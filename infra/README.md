# Terraform — eval-final-dgiti

Infraestructura como Código para la evaluación final DGITI (UPB Bucaramanga).

## Estructura

```
infra/
├── versions.tf            # Required providers y versiones
├── provider.tf            # AWS provider con default_tags
├── variables.tf           # Variables tipadas, descritas y validadas
├── main.tf                # VPC, subnets, IGW, NAT, SGs, ALB, ASG, RDS, ECR, CloudWatch
├── outputs.tf             # DNS ALB, ECR URL, RDS endpoint (sensitive), etc.
├── terraform.tfvars.example  # Plantilla (copiar a terraform.tfvars)
├── user_data.sh           # Bootstrap EC2 (docker pull + run + CW agent)
└── .gitignore             # Bloquea state, tfvars reales, planes
```

## Quickstart (AWS Academy)

### 1. Activar el Lab y exportar credenciales

```bash
# En AWS Academy → "Start Lab" → "AWS Details"
# Copia el bloque "AWS CLI" y exporta:
export AWS_ACCESS_KEY_ID="ASIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export AWS_DEFAULT_REGION="us-east-1"

aws sts get-caller-identity   # debe responder con tu cuenta del Lab
```

### 2. Preparar tfvars

```bash
cd infra/
cp terraform.tfvars.example terraform.tfvars
# Ajusta valores si quieres (defaults ya son sensatos)
```

### 3. Aplicar

```bash
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

### 4. Push primera imagen al ECR

Después del apply, ECR queda creado pero vacío. Las EC2 hacen retry de `docker pull` cada 30s hasta que exista imagen.

```bash
# Login a ECR
ECR_URL=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin "$ECR_URL"

# Build y push desde la raíz del repo
cd ..
docker build -t eval-final-dgiti:latest .
docker tag eval-final-dgiti:latest "$ECR_URL:latest"
docker push "$ECR_URL:latest"
```

### 5. Validar el servicio

```bash
ALB=$(terraform output -raw alb_dns_name)
curl "http://$ALB/health"
open "http://$ALB/docs"
```

### 6. Destruir al finalizar

```bash
terraform destroy -auto-approve
```

## Notas técnicas

- **Estado**: local (`terraform.tfstate`) por simplicidad. NO se sube al repo (`.gitignore`).
  Para producción real → S3 + DynamoDB backend.
- **Credenciales AWS Academy**: rotan al cerrar el Lab. Si la sesión expira,
  re-exportar variables `AWS_*` antes del próximo comando Terraform.
- **IAM**: no se crean roles nuevos (restricción Academy). Se reusa
  `LabInstanceProfile` para las EC2.
- **Secrets**: el password de RDS se genera con `random_password` y se marca
  `sensitive`. Visible solo con `terraform output db_password`.
- **Encryption**: habilitada en RDS (storage_encrypted) y EBS (encrypted).

## Mapeo a la rúbrica (25%)

| Requisito | Archivo |
|---|---|
| `provider.tf` | ✓ |
| `variables.tf` | ✓ con descripciones y validaciones |
| `main.tf` | ✓ red + cómputo + datos + observabilidad |
| `outputs.tf` | ✓ con outputs sensibles marcados |
| `terraform.tfvars.example` | ✓ sin secretos |
| `user_data.sh` | ✓ |
| `terraform init/plan/apply/output` | ✓ documentado |
