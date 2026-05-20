# Decisiones Técnicas — Evaluación Final DGITI

**Proyecto:** `eval-final-dgiti`
**Estudiante:** Johan David Rodríguez Castro (integrante único)
**Curso:** Diseño y Gestión de Infraestructura Tecnológica — UPB Bucaramanga
**Docente:** Omar Pinzón Ardila
**Fecha:** 2026-05-19
**Repo:** https://github.com/Yoyagm/eval-final-dgiti

---

## Stack y servicios

| Capa | Decisión | Justificación |
|---|---|---|
| Región | `us-east-1` | Compatibilidad total con AWS Academy; todos los servicios disponibles |
| Lenguaje/Framework | **FastAPI 0.110 + Python 3.11** | Swagger automático en `/docs`, async nativo, ideal para prueba de carga |
| ORM | SQLAlchemy 2.0 + asyncpg | Estándar Python para PostgreSQL async |
| Base de datos | **RDS PostgreSQL 15 Multi-AZ** (`db.t3.micro`) | Multi-AZ = réplica standby síncrona (cumple "réplica" del .md); free-tier-friendly |
| Cómputo | **EC2 + Auto Scaling Group** (2× `t3.micro` mínimo) | Visible para evidenciar HA en consola; balanceo real entre instancias |
| Balanceador | **Application Load Balancer (ALB)** | L7, métricas ricas en CloudWatch para el 30% de la rúbrica |
| Empaquetado | Docker (imagen en ECR) | Cumple Dockerfile del .md; pipeline lo construye y publica |
| Bootstrap EC2 | `user_data.sh` → `docker pull` desde ECR | Automatiza despliegue al lanzar instancia |
| CI/CD | **GitHub Actions** | Secrets nativos, gratis, fácil de demostrar |
| Carga | **k6** | Reporte rico (p95, error rate), ejecutable local |
| Observabilidad | **CloudWatch** (logs + métricas + dashboard) | Nativo de AWS, requerido por la rúbrica |
| IaC | **Terraform 1.6+** | Obligatorio por el .md |

## Topología de red

- **VPC** `/16`
- **2 AZ** (us-east-1a, us-east-1b)
- **4 subredes**:
  - 2 públicas (10.0.1.0/24, 10.0.2.0/24) → ALB + NAT Gateway
  - 2 privadas (10.0.11.0/24, 10.0.12.0/24) → EC2 + RDS
- **Internet Gateway** para subredes públicas
- **NAT Gateway** (1 en pública AZ-a) para salida de subredes privadas

## Seguridad — Security Groups (least privilege)

| SG | Ingress | Egress |
|---|---|---|
| `alb-sg` | 80/tcp desde 0.0.0.0/0 | a `app-sg` 8000 |
| `app-sg` | 8000/tcp desde `alb-sg` | a `db-sg` 5432, a Internet (vía NAT) |
| `db-sg` | 5432/tcp desde `app-sg` | — |

**Sin SSH desde Internet**; troubleshooting vía SSM Session Manager si Academy lo permite.

## Restricciones AWS Academy consideradas

- **Sin IAM users nuevos** → uso de `LabRole` para EC2 y de credenciales temporales del Lab para Terraform y GitHub Actions.
- **Credenciales temporales rotan** al cerrar el Lab → flujo documentado para refrescarlas antes de grabar.
- **Sesión limitada (~4h)** → mantener Lab abierto durante toda la grabación; `terraform destroy` al final.
- **Algunos servicios bloqueados** (ej. Organizations, ciertos roles IAM) → la arquitectura no depende de ellos.
- **`AWS_SESSION_TOKEN` obligatorio** además de access/secret key (no son credenciales permanentes).

## Trazabilidad con la rúbrica

| Criterio | Peso | Dónde se demuestra |
|---|---|---|
| Arquitectura | 10% | F1: diagrama + ARQUITECTURA.md |
| IaC Terraform | 25% | F3: init/plan/apply/output en vivo |
| Servicio desplegado | 10% | F4: curl + Swagger + consola |
| Pipeline CI/CD | 25% | F5: Actions verde + secrets + deploy a ECR/EC2 |
| Desempeño y monitoreo | 30% | F6: k6 + CloudWatch Dashboard + Target Group |
