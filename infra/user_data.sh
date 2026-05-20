#!/bin/bash
set -eu
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== eval-final-dgiti bootstrap iniciado ==="

# ----------------------------------------------------------------------------
# Variables inyectadas por Terraform via templatefile
# ----------------------------------------------------------------------------
AWS_REGION="${aws_region}"
CONTAINER_IMAGE="${container_image}"
DATABASE_URL='${database_url}'
APP_PORT="${app_port}"
LOG_GROUP="${log_group}"

# ----------------------------------------------------------------------------
# Instalar Docker (Amazon Linux 2023)
# ----------------------------------------------------------------------------
dnf update -y
dnf install -y docker amazon-cloudwatch-agent
systemctl enable --now docker

# ----------------------------------------------------------------------------
# Pull con retry — la imagen es publica en ghcr.io, no requiere login.
# Si el primer apply ocurre antes de que el pipeline publique, se reintenta.
# ----------------------------------------------------------------------------
echo "Esperando imagen publica: $CONTAINER_IMAGE"

until docker pull "$CONTAINER_IMAGE"; do
  echo "Imagen no disponible aun; reintentando en 30s..."
  sleep 30
done

# ----------------------------------------------------------------------------
# CloudWatch Agent para logs del contenedor (stdout/stderr -> CW Logs)
# ----------------------------------------------------------------------------
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/lib/docker/containers/*/*.log",
            "log_group_name": "$LOG_GROUP",
            "log_stream_name": "{instance_id}/docker",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "$LOG_GROUP",
            "log_stream_name": "{instance_id}/bootstrap",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s || echo "CloudWatch Agent no disponible (continuamos sin el)"

# ----------------------------------------------------------------------------
# Levantar el contenedor
# ----------------------------------------------------------------------------
docker rm -f eval-app 2>/dev/null || true

docker run -d \
  --name eval-app \
  --restart unless-stopped \
  -p "$APP_PORT:8000" \
  -e DATABASE_URL="$DATABASE_URL" \
  -e ENVIRONMENT=production \
  -e LOG_LEVEL=INFO \
  "$CONTAINER_IMAGE"

echo "=== Contenedor eval-app levantado en puerto $APP_PORT ==="
docker ps
