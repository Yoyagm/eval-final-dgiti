# Pipeline CI/CD — eval-final-dgiti

Tres workflows separados con responsabilidades claras.

```
.github/workflows/
├── ci.yml              # lint + test + docker build sanity   (push & PR)
├── cd.yml              # build + push ECR + ASG refresh      (push a main)
└── terraform-plan.yml  # fmt + init + validate + plan        (PR a main)
```

## Flujo

```
                    ┌──────────────────────────────────────────────┐
                    │  Developer abre PR a main                    │
                    └──────────────────────────────────────────────┘
                                     │
                ┌────────────────────┼────────────────────┐
                ▼                                         ▼
        ┌───────────────┐                         ┌────────────────┐
        │   ci.yml      │                         │ terraform-plan │
        │ lint + test + │                         │  fmt/init/     │
        │ docker build  │                         │  validate/plan │
        └───────────────┘                         └────────────────┘
                │                                         │
                └────────────────────┬────────────────────┘
                                     ▼
                          ┌────────────────────┐
                          │  PR mergeada a main │
                          └────────────────────┘
                                     │
                                     ▼
                          ┌────────────────────┐
                          │      cd.yml         │
                          │  build & push ECR   │
                          │  ASG instance       │
                          │  refresh (rolling)  │
                          └────────────────────┘
```

## Secretos requeridos en GitHub

`Settings → Secrets and variables → Actions → New repository secret`:

| Nombre | Valor | Fuente |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | `ASIA...` | AWS Academy → "AWS Details" |
| `AWS_SECRET_ACCESS_KEY` | `…` | AWS Academy → "AWS Details" |
| `AWS_SESSION_TOKEN` | `…` | AWS Academy → "AWS Details" (obligatorio) |
| `AWS_REGION` | `us-east-1` | constante |

⚠ **AWS Academy rota las credenciales al cerrar el Lab.** Antes de cada
sesión de demo / push de prueba:

1. Inicia el Lab.
2. Copia el bloque "AWS CLI" de "AWS Details".
3. Actualiza los 3 secrets en GitHub (no `AWS_REGION`).

## Triggers

| Workflow | Push main | PR main | Manual |
|---|---|---|---|
| `ci.yml` | ✅ | ✅ | ✅ |
| `cd.yml` | ✅ | ❌ | ✅ |
| `terraform-plan.yml` | ❌ | ✅ (si toca `infra/`) | ✅ |

## Jobs y stages

### `ci.yml` — validación de código
1. **lint** — `ruff check` + `ruff format --check`
2. **test** — `pytest` con coverage XML, enforcement ≥70%, sube `coverage.xml` como artefacto
3. **docker-build** — `docker build` sin push (sanity check del Dockerfile)

### `cd.yml` — despliegue
1. **build-and-push** — login ECR, build, push con tag `latest` + `SHA-corto`
2. **refresh-asg** — `aws autoscaling start-instance-refresh` rolling (50% healthy mínimo)

### `terraform-plan.yml` — validación de infra
1. `terraform fmt -check`
2. `terraform init -backend=false`
3. `terraform validate`
4. `terraform plan -out=tfplan`
5. Comenta el resumen en el PR

## Cómo demostrarlo en el video (rúbrica 25%)

1. **Settings → Secrets** — mostrar los 4 secrets (nombres, no valores)
2. **Pull Request abierto** — ver `ci.yml` y `terraform-plan.yml` corriendo en checks
3. **Hacer un commit pequeño en `main`** (cambio en README o bump de versión)
4. **Pestaña Actions** — ver `cd.yml` corriendo:
   - login a ECR
   - build de imagen con cache
   - push con 2 tags
   - ASG instance refresh
5. **Consola AWS → ECR** — nueva imagen con el SHA del commit
6. **Consola AWS → EC2 → Auto Scaling Groups** — refresh en progreso
7. **Job summary** — bloque markdown con URI de la imagen y refresh ID

## Comandos manuales útiles

```bash
# Disparar CD manualmente con tag custom
gh workflow run cd.yml -f image_tag=demo-video-v1

# Ver runs recientes
gh run list --workflow=ci.yml --limit 5

# Ver un run específico
gh run view <run-id> --log
```
