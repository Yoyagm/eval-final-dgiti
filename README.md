# eval-final-dgiti

**Evaluación Final — Diseño y Gestión de Infraestructura Tecnológica**
Universidad Pontificia Bolivariana, Seccional Bucaramanga
Estudiante: Johan David Rodríguez Castro
Docente: Omar Pinzón Ardila

[![CI](https://github.com/Yoyagm/eval-final-dgiti/actions/workflows/ci.yml/badge.svg)](https://github.com/Yoyagm/eval-final-dgiti/actions/workflows/ci.yml)
[![CD](https://github.com/Yoyagm/eval-final-dgiti/actions/workflows/cd.yml/badge.svg)](https://github.com/Yoyagm/eval-final-dgiti/actions/workflows/cd.yml)
[![Terraform Plan](https://github.com/Yoyagm/eval-final-dgiti/actions/workflows/terraform-plan.yml/badge.svg)](https://github.com/Yoyagm/eval-final-dgiti/actions/workflows/terraform-plan.yml)

## Resumen

Infraestructura AWS HA con FastAPI + PostgreSQL desplegada vía Terraform y orquestada por GitHub Actions.

## Estructura del repositorio

```
eval-final-dgiti/
├── app/                    # Servicio FastAPI
├── tests/                  # Tests pytest
├── infra/                  # Terraform (VPC, ALB, ASG, RDS, SGs)
├── load/                   # Pruebas de carga k6
├── docs/                   # Diagrama, decisiones, guion del video
├── .github/workflows/      # CI/CD Pipeline
├── Dockerfile
└── README.md
```

## Stack

- **Backend:** FastAPI 0.110 + Python 3.11 + SQLAlchemy 2.0
- **BD:** PostgreSQL 15 (RDS Multi-AZ)
- **Cómputo:** EC2 + Auto Scaling Group (2 instancias mín en 2 AZ)
- **Balanceador:** Application Load Balancer
- **IaC:** Terraform 1.6+
- **CI/CD:** GitHub Actions → ECR → EC2
- **Observabilidad:** CloudWatch (logs + métricas + dashboard)
- **Carga:** k6

## Endpoints principales

| Método | Path | Descripción |
|---|---|---|
| GET | `/health` | Health check (incluye verificación BD) |
| GET | `/docs` | Swagger UI |
| GET | `/api/items` | Listar items |
| POST | `/api/items` | Crear item |

## Documentación

- `docs/ARQUITECTURA.md` — Diseño y justificación
- `docs/DECISIONES_TECNICAS.md` — Trade-offs y decisiones
- `docs/GUION_VIDEO.md` — Guion del demo
- `docs/diagrama.png` — Diagrama AWS 2026

## Quickstart local

```bash
# App local con docker-compose
docker compose up --build

# Tests
pytest --cov=app tests/

# Terraform (requiere AWS Academy Lab activo)
cd infra
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -auto-approve
terraform output
```
