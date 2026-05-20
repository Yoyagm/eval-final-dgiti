#!/bin/bash
set -eu
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== eval-final-dgiti bootstrap iniciado ==="

# ----------------------------------------------------------------------------
# Variables inyectadas por Terraform via templatefile
# ----------------------------------------------------------------------------
AWS_REGION="${aws_region}"
ECR_REPO_URL="${ecr_repo_url}"
IMAGE_TAG="${image_tag}"
DATABASE_URL='${database_url}'
APP_PORT="${app_port}"
LOG_GROUP="${log_group}"

# ----------------------------------------------------------------------------
# Instalar Docker y AWS CLI (Amazon Linux 2023 trae cli v2 preinstalado)
# ----------------------------------------------------------------------------
dnf update -y
dnf install -y docker amazon-cloudwatch-agent
systemctl enable --now docker

# ----------------------------------------------------------------------------
# Login a ECR (LabRole de AWS Academy ya tiene AmazonEC2ContainerRegistryReadOnly)
# ----------------------------------------------------------------------------
ECR_REGISTRY="$(echo "$ECR_REPO_URL" | cut -d/ -f1)"
echo "Autenticando en ECR registry: $ECR_REGISTRY"

# Retry login hasta 5 veces (LabRole tarda unos segundos en propagar)
for i in 1 2 3 4 5; do
  if aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"; then
    echo "Login ECR OK en intento $i"
    break
  fi
  echo "Intento $i de login ECR falló, reintentando en 10s..."
  sleep 10
done

# ----------------------------------------------------------------------------
# Pull con retry — la imagen puede no existir aún si es el primer apply
# (CI/CD la subirá; el contenedor se levantará cuando aparezca)
# ----------------------------------------------------------------------------
IMAGE_REF="$ECR_REPO_URL:$IMAGE_TAG"
echo "Esperando imagen Docker: $IMAGE_REF"

until docker pull "$IMAGE_REF"; do
  echo "Imagen no disponible aún; reintentando en 30s..."
  sleep 30
done

# ----------------------------------------------------------------------------
# CloudWatch Agent para logs de docker (stdout/stderr → CW Logs)
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
  -s || echo "CloudWatch Agent no disponible (continuamos sin él)"

# ----------------------------------------------------------------------------
# Levantar el contenedor de la app
# ----------------------------------------------------------------------------
docker rm -f eval-app 2>/dev/null || true

docker run -d \
  --name eval-app \
  --restart unless-stopped \
  -p "$APP_PORT:8000" \
  -e DATABASE_URL="$DATABASE_URL" \
  -e ENVIRONMENT=production \
  -e LOG_LEVEL=INFO \
  -e APP_VERSION="$IMAGE_TAG" \
  "$IMAGE_REF"

echo "=== Contenedor eval-app levantado en puerto $APP_PORT ==="
docker ps
