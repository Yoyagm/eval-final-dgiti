# 🎬 Guion Definitivo de Grabación — eval-final-dgiti

> **Duración objetivo:** ≤ 10:00
> **Modalidad:** demostración en vivo, integrante único, cuenta AWS Academy
> **Repo:** https://github.com/Yoyagm/eval-final-dgiti
> **ALB DNS desplegado:** `eval-final-dgiti-alb-217333176.us-east-1.elb.amazonaws.com`
> **Versión del guion:** revisada con la infra real desplegada y validada

## Distribución por peso de rúbrica

| Bloque | Tiempo | Peso | Acumulado |
|---|---|---|---|
| Intro + Arquitectura | 0:30 | 10% | 0:30 |
| IaC Terraform | 2:30 | 25% | 3:00 |
| Servicio desplegado | 1:00 | 10% | 4:00 |
| Pipeline CI/CD | 2:30 | 25% | 6:30 |
| Desempeño + monitoreo | 3:00 | 30% | 9:30 |
| Cierre | 0:30 | — | 10:00 |

---

# 🧱 PARTE 0 — Una sola tarea pendiente (5 min)

## Exportar el diagrama a PNG

1. Abre https://app.diagrams.net/
2. **File → Open from → Device** → `docs/diagrama.drawio`
3. Aparece el diagrama con iconos AWS 2026
4. **File → Export as → PNG** (Zoom 200%, Border 20, Background White)
5. Guarda como `docs/diagrama.png`
6. Sube al repo:
   ```bash
   cd ~/Desktop/infra/eval-final-dgiti
   git add docs/diagrama.png
   git commit -m "docs: agrega diagrama PNG con iconos AWS 2026"
   git push
   ```

---

# 📋 PARTE 1 — Lo que ya está hecho ✓

Lo siguiente ya está aplicado y validado. No hay que repetirlo:

- ✅ AWS Academy Lab iniciado
- ✅ Credenciales exportadas y guardadas en `~/.aws/credentials`
- ✅ 4 secrets configurados en GitHub
- ✅ `terraform apply` ejecutado exitosamente
- ✅ Imagen Docker publicada en ghcr.io (pública)
- ✅ App respondiendo en el ALB (`/health` → 200, `db=connected`)
- ✅ 5 items sembrados en BD
- ✅ `./scripts/test_endpoints.sh` → 8/8 PASS
- ✅ CI verde confirmado

---

# 🚀 PARTE 1.5 — Lo último que falta antes de grabar

## a) Disparar pipeline CI + CD para tener un run reciente

```bash
gh workflow run ci.yml -R Yoyagm/eval-final-dgiti --ref main
gh workflow run cd.yml -R Yoyagm/eval-final-dgiti --ref main
sleep 8
gh run list -R Yoyagm/eval-final-dgiti --limit 3
# Espera ~4 min hasta que ambos terminen "success"
```

## b) Verificación final 1 min antes de grabar

```bash
cd ~/Desktop/infra/eval-final-dgiti
export ALB=$(cd infra && terraform output -raw alb_dns_name)
export DASH=$(cd infra && terraform output -raw cloudwatch_dashboard_url)

echo "ALB:       $(curl -so /dev/null -w '%{http_code}' http://$ALB/health)"
echo "CI:        $(gh run list -R Yoyagm/eval-final-dgiti -w ci.yml -L 1 --json conclusion -q '.[0].conclusion')"
echo "CD:        $(gh run list -R Yoyagm/eval-final-dgiti -w cd.yml -L 1 --json conclusion -q '.[0].conclusion')"
echo "Diagrama:  $(test -f docs/diagrama.png && echo OK || echo FALTA)"
echo ""
echo "ALB URL:   http://$ALB"
echo "DASH URL:  $DASH"
```

Esperado:
```
ALB:       200
CI:        success
CD:        success
Diagrama:  OK
```

---

# 🖥️ PARTE 2 — Setup físico (10 min antes de REC)

## 2.1 · Pre-abrir 12 tabs en el navegador (en este orden)

| # | URL | Para bloque |
|---|---|---|
| 1 | `docs/diagrama.png` (visor) | Arquitectura |
| 2 | `https://us-east-1.console.aws.amazon.com/vpcconsole/home?region=us-east-1#vpcs:` | IaC |
| 3 | `https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#LoadBalancers:` | IaC |
| 4 | `https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#TargetGroups:` | IaC + Desempeño |
| 5 | `https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#Instances:` (filtrar `Project=eval-final-dgiti`) | IaC |
| 6 | `https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#AutoScalingGroups:` | IaC + CI/CD |
| 7 | `https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#SecurityGroups:` (filtrar `eval-final`) | IaC |
| 8 | `http://eval-final-dgiti-alb-217333176.us-east-1.elb.amazonaws.com/docs` | Servicio |
| 9 | `https://github.com/Yoyagm/eval-final-dgiti/settings/secrets/actions` | CI/CD |
| 10 | `https://github.com/Yoyagm/eval-final-dgiti/actions` | CI/CD |
| 11 | `https://github.com/Yoyagm/eval-final-dgiti/pkgs/container/eval-final-dgiti` | CI/CD (registry, accedido desde el repo) |
| 12 | El Dashboard CloudWatch — pega `terraform output -raw cloudwatch_dashboard_url` | Desempeño |

## 2.2 · Terminal

```bash
cd ~/Desktop/infra/eval-final-dgiti
export ALB=$(cd infra && terraform output -raw alb_dns_name)
export DASH=$(cd infra && terraform output -raw cloudwatch_dashboard_url)
echo "ALB=$ALB"
echo "DASH=$DASH"
```

- Tamaño grande (ocupando toda la pantalla)
- Font ≥ 16pt
- Pane izquierdo: comandos / Pane derecho: durante k6 mostrará progreso

## 2.3 · Webcam + audio

- Webcam ON, esquina inferior derecha
- Micrófono probado
- **Do Not Disturb** activado
- Cierra Slack, Mail, notificaciones

---

# 🎥 PARTE 3 — Guion de grabación segundo a segundo

> Frases entre comillas: guía. Dilas con tus palabras.
> Bloques en código: comandos exactos a pegar.

---

## ⏱ 00:00 — 00:30 · Intro + Arquitectura (10%)

### Pantalla: webcam grande + diagrama.png a pantalla completa

### Decir (≈25s):
> "Hola, soy **Johan Rodríguez**. Como integrante único, voy a sustentar la evaluación final del curso de Diseño y Gestión de Infraestructura Tecnológica.
>
> Esta es la arquitectura: **VPC en us-east-1 con dos zonas de disponibilidad**. Subredes públicas para el **Application Load Balancer** y NAT; subredes privadas con **dos EC2 corriendo FastAPI** tras un Auto Scaling Group, y **PostgreSQL desplegado en dos EC2 dedicadas** — una primary y una replica con streaming replication, completamente aisladas de Internet.
>
> **GitHub Container Registry** almacena la imagen Docker, **GitHub Actions** maneja el CI/CD, y **CloudWatch** centraliza métricas, logs y alarmas. La seguridad usa **tres Security Groups en cascada** con least-privilege."

> 💡 **Por qué Postgres en EC2 y no RDS:** menciónalo brevemente si quieres reforzar criterio técnico — "el Lab Academy restringe servicios gestionados como RDS y ECR; implementé equivalentes funcionales manteniendo todos los requisitos no funcionales."

---

## ⏱ 00:30 — 03:00 · Infraestructura como Código (25%)

### 00:30 — Estructura del repo Terraform (20s)

```bash
ls infra/
```

> "Terraform organizado como pide la rúbrica: **provider.tf**, **variables.tf**, **main.tf**, **outputs.tf**, **terraform.tfvars.example** sin secretos, **user_data.sh** para las EC2 de la app, y **user_data_db_primary.sh** y **user_data_db_replica.sh** para el cluster de PostgreSQL."

### 00:50 — Variables tipadas (10s)

```bash
head -30 infra/variables.tf
```

> "Variables tipadas, descritas, con **validaciones regex**. No hay valores hardcoded."

### 01:00 — init, validate, plan, output (50s)

```bash
cd infra
terraform init -upgrade | tail -5
```
> "**init**: providers descargados."

```bash
terraform validate
```
> "**validate**: configuración válida."

```bash
terraform plan | tail -10
```
> "**plan**: el state está sincronizado con la realidad. Sin cambios pendientes."

```bash
terraform output
```
> "**output**: DNS del ALB, URL del dashboard CloudWatch, IPs privadas de los nodos de BD marcadas como sensitive — los secretos nunca se imprimen en claro."

### 01:50 — Tab 2 (VPC): mostrar VPC + 4 subredes (15s)

> "VPC con sus cuatro subredes: dos públicas en CIDR 10.0.1 y 10.0.2, dos privadas en 10.0.11 y 10.0.12. Cada una etiquetada con su Tier — public o private."

### 02:05 — Tab 3 (ALB): mostrar listener (12s)

> "El ALB está active, internet-facing, con un listener HTTP en el puerto 80 que forwarda al target group."

### 02:17 — Tab 4 (Target Group): 2 targets healthy (12s)

> "Los **dos targets están healthy**, uno en cada AZ — HA real, no teórica."

### 02:29 — Tab 5 (Instances): mostrar las 4 EC2 (15s)

Filtra por `Project=eval-final-dgiti`. Verás 4 instancias.

> "Cuatro instancias EC2 corriendo: **dos para la aplicación** detrás del ALB, **una primary de PostgreSQL** en us-east-1a, **una replica de PostgreSQL** en us-east-1b — todo en subredes privadas, sin IPs públicas."

### 02:44 — Tab 7 (Security Groups): mostrar 3 SGs (16s)

Filtra por `eval-final`. Click en `app-sg`, mostrar pestaña **Inbound rules**.

> "Tres Security Groups en cascada. El **app-sg** acepta tráfico solo desde el **alb-sg** en el puerto 8000. El **db-sg** acepta tráfico solo desde el **app-sg** en el puerto 5432, y tiene una regla self para permitir la replicación entre los nodos de BD. Least-privilege en cada capa."

---

## ⏱ 03:00 — 04:00 · Servicio desplegado (10%)

### 03:00 — curl al health (15s)

```bash
curl -s "http://$ALB/health" | jq
```

> "El endpoint `/health` responde 200 con la verificación de la conexión a la base de datos. La estructura es `data` con el estado y `meta` con el request ID propagado."

### 03:15 — Suite de validación (25s)

```bash
./scripts/test_endpoints.sh
```

> "Este script valida **8 escenarios**: root, health, OpenAPI schema, listado, creación 201, validación pydantic 422, 404 cuando no existe, y paginación. Latencia por request en colores. **8 de 8 en verde**."

### 03:40 — Tab 8 (Swagger): POST en vivo (15s)

En `http://$ALB/docs`:
- Click **POST /api/items** → **Try it out**
- En body: `{"name": "Demo en vivo durante video", "description": "creado desde Swagger"}`
- **Execute**

> "FastAPI expone Swagger interactivo. Hago un POST en vivo desde el navegador. La app responde 201 con el item creado y su ID auto-generado por PostgreSQL."

### 03:55 — Cerrar bloque (5s)

> "Y eso se persiste en la base de datos real — no es una BD en memoria."

---

## ⏱ 04:00 — 06:30 · Pipeline CI/CD (25%)

### 04:00 — Mostrar workflows (15s)

```bash
ls .github/workflows/
```

> "Tres workflows: **ci.yml** hace lint con ruff y tests con pytest en cada PR; **cd.yml** construye la imagen Docker y la publica en **GitHub Container Registry**; **terraform-plan.yml** valida cambios de infraestructura."

### 04:15 — Tab 9 (Secrets): 4 secrets (15s)

> "**Cuatro secrets** configurados en GitHub: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN, y AWS_REGION. Valores enmascarados — las credenciales nunca aparecen en los YAML."

### 04:30 — Disparar pipeline (10s)

```bash
gh workflow run ci.yml -R Yoyagm/eval-final-dgiti --ref main
gh workflow run cd.yml -R Yoyagm/eval-final-dgiti --ref main
```

> "Disparo los pipelines manualmente con `workflow_dispatch` — útil para re-ejecuciones sin necesidad de hacer un push."

### 04:40 — Tab 10 (Actions): pipelines corriendo (90s)

> "Aquí está el pipeline corriendo. **CI** arranca con ruff para lint, luego pytest con cobertura del **82%**, finalmente un sanity build de Docker. Tiempo total **alrededor de dos minutos**.
>
> En paralelo **CD**: configura credenciales AWS para el segundo job, hace login en ghcr.io con el GITHUB_TOKEN, construye con cache de capas, y publica con **dos tags** — latest y el SHA del commit para trazabilidad."

### 06:10 — Tab 11 (GitHub Packages): mostrar imagen (15s)

> "Aquí está la **imagen publicada en GHCR**, pública para que las EC2 hagan pull sin login, con el tag del SHA del commit y latest."

### 06:25 — Tab 6 (ASG): instance refresh (5s)

> "El segundo job del CD también dispara un **instance refresh rolling** en el Auto Scaling Group, manteniendo el 50% de instancias healthy. Despliegue zero-downtime."

---

## ⏱ 06:30 — 09:30 · Desempeño y monitoreo (30%) — **EL BLOQUE MÁS IMPORTANTE**

### Pantalla: split-screen — terminal con k6 + Tab 12 (Dashboard CloudWatch)

### 06:30 — Lanzar k6 (15s)

```bash
BASE_URL="http://$ALB" k6 run load/load_test.js
```

> "Lanzo una prueba de carga con **k6**: ramp-up de 30 segundos hasta **50 usuarios virtuales**, sostener 50 VUs durante 2 minutos, ramp-down de 30 segundos. **Mix realista: 70% lecturas, 20% creaciones, 10% health checks**. Cinco thresholds que fallan el test si se exceden — p95 bajo 1.5 segundos y error rate bajo 5%."

### 06:45 — Tab 12 (Dashboard): fila 1 ALB (45s)

> "En CloudWatch ven cómo **RequestCount sube en sincronía** con el ramp-up. **TargetResponseTime p95** se mantiene bajo el umbral. **Cero errores 5XX**. Y los **dos targets healthy** estables — la infra absorbe la carga."

### 07:30 — Tab 12: fila 2 (CPU per instance) — **MOMENTO CRÍTICO** (60s)

Scroll a la fila 2 del dashboard.

> "**Aquí está la prueba del balanceador funcionando**: en CPU por instancia hay **dos líneas paralelas casi pegadas** — el ALB distribuye el tráfico entre las dos instancias en proporción cercana al **50/50**. Si una sola instancia recibiera todo, vería una línea al 100% y la otra plana. Lo mismo en NetworkIn y NetworkOut: tráfico equilibrado."

### 08:30 — Tab 12: fila 3 (DB primary vs replica) (30s)

Scroll a la fila 3.

> "Aquí comparo el comportamiento de la **base de datos primary contra la replica**. El primary recibe escrituras del 20% del tráfico POST, vean cómo su NetworkOut crece — porque está enviando el WAL al replica vía streaming replication. La CPU se mantiene controlada en ambos nodos, lejos del umbral del 80% de la alarma."

### 09:00 — Resumen k6 (20s)

Vuelve al terminal.

> "Resultado: **N requests**, **p95 de X milisegundos**, **error rate de Y por ciento**, **Z items creados**. **Todos los thresholds aprobados**. La infraestructura cumple los requisitos no funcionales bajo carga sostenida."

### 09:20 — Alarmas OK (10s)

> "Y las **cuatro alarmas** — 5XX altos, healthy hosts bajo, CPU EC2 app alto y CPU DB primary alto — permanecieron en **estado OK** durante toda la prueba."

---

## ⏱ 09:30 — 10:00 · Cierre (30s)

### Pantalla: webcam grande + tab del repo

> "Repositorio público en **github.com/Yoyagm/eval-final-dgiti**. Toda la infraestructura como código, el servicio con **19 tests y 82% de cobertura**, los tres workflows de CI/CD, los scripts de validación, la prueba de carga y la observabilidad están versionados.
>
> Para cumplir buenas prácticas con AWS Academy, al cerrar este video ejecuto **terraform destroy**. Gracias **profesor Omar Pinzón**."

### Opcional final:
```bash
cd ~/Desktop/infra/eval-final-dgiti/infra
terraform destroy -auto-approve &
# Muestra que arranca y corta video
```

---

# 🧹 PARTE 4 — Post-grabación

```bash
cd ~/Desktop/infra/eval-final-dgiti/infra
terraform destroy -auto-approve
# ~10 min, espera a que termine
```

Cerrar el Lab AWS Academy.

## Checklist revisión video

- [ ] Duración ≤ 10:00
- [ ] Audio claro y sincronizado
- [ ] Cara visible en intro y cierre
- [ ] Outputs reales de Terraform (no slides)
- [ ] Consola AWS Academy con MI cuenta visible
- [ ] Dashboard CloudWatch con métricas reales durante k6
- [ ] **Dos líneas paralelas de CPU per instance** visibles (clave 30%)
- [ ] **Dos líneas separadas DB primary vs replica** visibles
- [ ] Workflows verdes en GitHub Actions
- [ ] SHA del commit coincidiendo entre GitHub Actions y GHCR
- [ ] `terraform destroy` iniciando

---

# 🆘 Plan B global

Si algo falla en VIVO y no se arregla en 30s: **reconoce el problema, explica qué debería pasar, y avanza al siguiente bloque**. La rúbrica valora comprensión técnica, no perfección.

Si NADA funciona en AWS: graba sobre lo construido localmente con `docker compose up` — cubres servicio + tests + CI/CD verde en GitHub. Solo perderías el bloque AWS visual.

---

# 📞 Comandos rápidos de referencia

```bash
# Variables base (téngalas exportadas durante toda la grabación)
export ALB=$(cd infra && terraform output -raw alb_dns_name)
export DASH=$(cd infra && terraform output -raw cloudwatch_dashboard_url)

# Verificaciones rápidas
curl -s "http://$ALB/health" | jq
./scripts/test_endpoints.sh
gh run list -R Yoyagm/eval-final-dgiti --limit 5

# Disparar pipelines manualmente
gh workflow run ci.yml -R Yoyagm/eval-final-dgiti --ref main
gh workflow run cd.yml -R Yoyagm/eval-final-dgiti --ref main

# Carga
BASE_URL="http://$ALB" k6 run load/load_test.js

# Ver target health del ALB
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names eval-final-dgiti-tg --query 'TargetGroups[0].TargetGroupArn' --output text)

# Ver consola de output de una instancia (debug user_data)
aws ec2 get-console-output --instance-id <ID> --region us-east-1 | tail -80

# Limpieza
cd infra && terraform destroy -auto-approve
```
