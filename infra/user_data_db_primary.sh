#!/bin/bash
set -eu
exec > >(tee /var/log/user-data.log | logger -t db-primary -s 2>/dev/console) 2>&1

echo "=== eval-final-dgiti DB PRIMARY bootstrap ==="

DB_USER="${db_username}"
DB_PASSWORD='${db_password}'
DB_NAME="${db_name}"
REPLICATION_PASSWORD='${replication_password}'
VPC_CIDR="${vpc_cidr}"
LOG_GROUP="${log_group}"

# Instalar Docker
dnf update -y
dnf install -y docker amazon-cloudwatch-agent
systemctl enable --now docker

# Volumen persistente
mkdir -p /var/lib/postgres-data

# Levantar PostgreSQL 15 como primary con replicacion habilitada
docker run -d \
  --name postgres-primary \
  --restart unless-stopped \
  -p 5432:5432 \
  -v /var/lib/postgres-data:/var/lib/postgresql/data \
  -e POSTGRES_USER="$DB_USER" \
  -e POSTGRES_PASSWORD="$DB_PASSWORD" \
  -e POSTGRES_DB="$DB_NAME" \
  -e POSTGRES_INITDB_ARGS="--auth-host=scram-sha-256" \
  postgres:15-alpine \
  -c wal_level=replica \
  -c max_wal_senders=5 \
  -c max_replication_slots=5 \
  -c hot_standby=on \
  -c listen_addresses='*'

# Esperar a que postgres este listo
echo "Esperando a que PostgreSQL primary este listo..."
for i in $(seq 1 30); do
  if docker exec postgres-primary pg_isready -U "$DB_USER" >/dev/null 2>&1; then
    echo "Primary listo."
    break
  fi
  sleep 2
done

# Crear usuario de replicacion
docker exec postgres-primary psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 <<SQL
CREATE ROLE replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD '$REPLICATION_PASSWORD';
SQL

# Permitir replicacion desde la VPC en pg_hba.conf
docker exec postgres-primary bash -c "echo 'host replication replicator $VPC_CIDR scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf"
docker exec postgres-primary bash -c "echo 'host all all $VPC_CIDR scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf"

# Reload config
docker exec postgres-primary psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT pg_reload_conf();"

# CloudWatch Agent para logs
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/lib/docker/containers/*/*.log",
            "log_group_name": "$LOG_GROUP",
            "log_stream_name": "{instance_id}/db-primary",
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

echo "=== DB primary listo en puerto 5432 ==="
docker ps
