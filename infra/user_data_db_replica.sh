#!/bin/bash
set -eu
exec > >(tee /var/log/user-data.log | logger -t db-replica -s 2>/dev/console) 2>&1

echo "=== eval-final-dgiti DB REPLICA bootstrap ==="

DB_USER="${db_username}"
REPLICATION_PASSWORD='${replication_password}'
PRIMARY_IP="${primary_ip}"
LOG_GROUP="${log_group}"

dnf update -y
dnf install -y docker amazon-cloudwatch-agent
systemctl enable --now docker

mkdir -p /var/lib/postgres-data

# Esperar a que el primary este listo
echo "Esperando a que primary $PRIMARY_IP:5432 este listo..."
for i in $(seq 1 60); do
  if docker run --rm postgres:15-alpine pg_isready -h "$PRIMARY_IP" -p 5432 -U "$DB_USER" >/dev/null 2>&1; then
    echo "Primary alcanzable."
    break
  fi
  sleep 5
done

# pg_basebackup desde el primary
echo "Ejecutando pg_basebackup..."
docker run --rm \
  -v /var/lib/postgres-data:/var/lib/postgresql/data \
  -e PGPASSWORD="$REPLICATION_PASSWORD" \
  postgres:15-alpine \
  bash -c "rm -rf /var/lib/postgresql/data/* && pg_basebackup -h $PRIMARY_IP -p 5432 -D /var/lib/postgresql/data -U replicator -P -v -R -X stream -C -S replica_slot"

# Permisos correctos para el volumen
chown -R 70:70 /var/lib/postgres-data

# Levantar postgres como standby (la flag -R de pg_basebackup ya crea standby.signal)
docker run -d \
  --name postgres-replica \
  --restart unless-stopped \
  -p 5432:5432 \
  -v /var/lib/postgres-data:/var/lib/postgresql/data \
  postgres:15-alpine \
  -c hot_standby=on \
  -c listen_addresses='*'

# CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/lib/docker/containers/*/*.log",
            "log_group_name": "$LOG_GROUP",
            "log_stream_name": "{instance_id}/db-replica",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOF
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s || true

echo "=== DB replica corriendo en standby ==="
docker ps
