# 🎬 Guion definitivo de grabación — eval-final-dgiti

> **Duración objetivo:** ≤ 10:00
> **Modalidad:** demo en vivo, integrante único, cuenta AWS Academy
> **Distribución por peso de rúbrica:**

| Bloque | Tiempo | Peso | Acumulado |
|---|---|---|---|
| Intro + Arquitectura | 0:30 | 10% | 0:30 |
| IaC Terraform | 2:30 | 25% | 3:00 |
| Servicio desplegado | 1:00 | 10% | 4:00 |
| Pipeline CI/CD | 2:30 | 25% | 6:30 |
| Desempeño + monitoreo | 3:00 | 30% | 9:30 |
| Cierre | 0:30 | — | 10:00 |

---

# 📋 PARTE 1 — Preparación previa (T-45 min antes de grabar)

Esto **NO se graba**. Es para tener todo verde y listo cuando empieces a grabar.

## Paso 1 · Iniciar Lab y credenciales (5 min)

```bash
# 1. Abre AWS Academy en navegador → tu curso → módulo → "Start Lab"
# 2. Espera el punto verde junto a "AWS"
# 3. Click en "AWS Details" → muestra "AWS CLI"
# 4. Copia el bloque completo y pégalo aquí:

cat > ~/.aws/credentials <<'EOF'
[default]
aws_access_key_id=ASIA...
aws_secret_access_key=...
aws_session_token=...
EOF

# 5. Verifica
export AWS_REGION=us-east-1
aws sts get-caller-identity
# Debe responder con tu cuenta del Lab
```

## Paso 2 · Aplicar Terraform (10-15 min)

```bash
cd ~/Desktop/infra/eval-final-dgiti/infra

# Copia tfvars si no existe aún
[[ -f terraform.tfvars ]] || cp terraform.tfvars.example terraform.tfvars

terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
# ~8-12 min: la creación de RDS Multi-AZ tarda lo suyo
```

Cuando termine guarda los outputs:
```bash
terraform output alb_dns_name
terraform output ecr_repository_url
terraform output -raw cloudwatch_dashboard_url
```

## Paso 3 · Push primera imagen a ECR (5 min)

```bash
cd ~/Desktop/infra/eval-final-dgiti

ECR_URL=$(cd infra && terraform output -raw ecr_repository_url)
ECR_REGISTRY=$(echo "$ECR_URL" | cut -d/ -f1)

aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker build -t eval-final-dgiti:latest .
docker tag eval-final-dgiti:latest "$ECR_URL:latest"
docker push "$ECR_URL:latest"
```

Espera 1-2 minutos. Las EC2 detectan la imagen y la levantan.

## Paso 4 · Verificar servicio + sembrar datos (3 min)

```bash
ALB=$(cd infra && terraform output -raw alb_dns_name)

# Esperar a que el ALB responda 200
until curl -sf "http://$ALB/health" >/dev/null; do
  echo "Esperando ALB..."; sleep 10
done
echo "ALB OK"

# Sembrar items
./scripts/seed_data.sh

# Validar
./scripts/test_endpoints.sh
# Debe terminar: 8 pass • 0 fail
```

## Paso 5 · Configurar GitHub secrets (5 min)

En `https://github.com/Yoyagm/eval-final-dgiti/settings/secrets/actions`:

| Secret | Valor |
|---|---|
| `AWS_ACCESS_KEY_ID` | (del Lab) |
| `AWS_SECRET_ACCESS_KEY` | (del Lab) |
| `AWS_SESSION_TOKEN` | (del Lab) |
| `AWS_REGION` | `us-east-1` |

## Paso 6 · Disparar pipeline al menos una vez (5 min)

```bash
cd ~/Desktop/infra/eval-final-dgiti
git add .
git commit -m "ci: trigger inicial para evaluación"
git push origin main
```

Abre `https://github.com/Yoyagm/eval-final-dgiti/actions` y espera a que **ci.yml + cd.yml** terminen verde (~5 min).

## Paso 7 · Setup físico de la grabación (T-10 min)

### Pestañas del navegador (en este orden, izq a der)
1. `https://github.com/Yoyagm/eval-final-dgiti` (repo)
2. `https://github.com/Yoyagm/eval-final-dgiti/actions` (Actions)
3. `https://github.com/Yoyagm/eval-final-dgiti/settings/secrets/actions` (Secrets)
4. `docs/diagrama.png` (abierto en visor)
5. `https://us-east-1.console.aws.amazon.com/vpcconsole/home?region=us-east-1#vpcs:` (VPC)
6. `https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#LoadBalancers:` (ALB)
7. `https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#TargetGroups:` (Target Group)
8. `https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#AutoScalingGroups:` (ASG)
9. `https://us-east-1.console.aws.amazon.com/rds/home?region=us-east-1#databases:` (RDS)
10. `https://us-east-1.console.aws.amazon.com/ecr/repositories?region=us-east-1` (ECR)
11. `terraform output -raw cloudwatch_dashboard_url` (Dashboard CloudWatch) — copia y pega
12. `http://$ALB/docs` (Swagger del servicio)

### Terminal
- **Pane izquierdo:** comandos
- **Pane derecho:** durante k6, mostrar métricas en vivo
- Ubícate en: `~/Desktop/infra/eval-final-dgiti/`
- Webcam encendida en esquina inferior derecha
- Audio probado

### Variables a tener visibles (anotadas en post-it virtual)
```
ALB_DNS:     eval-final-dgiti-alb-XXXXXXXX.us-east-1.elb.amazonaws.com
ECR_URL:     <account>.dkr.ecr.us-east-1.amazonaws.com/eval-final-dgiti
DASHBOARD:   https://us-east-1.console.aws.amazon.com/cloudwatch/...
```

---

# 🎥 PARTE 2 — Guion de la grabación en vivo

> Lee tranquilo. **Cada bloque tiene comandos copiables y la frase que dices.**
> Las frases son guía: dilas con tus palabras, no como lectura mecánica.

---

## ⏱ 00:00 — 00:30 · Arquitectura (10%)

**Pantalla:** webcam grande + `docs/diagrama.png`

**Comando previo:** abrir `diagrama.png` a pantalla completa.

**Narración:**
> "Hola, soy Johan Rodríguez. Como integrante único, voy a sustentar la evaluación final de DGITI. Esta es la arquitectura que diseñé: una VPC en us-east-1 con dos zonas de disponibilidad. En las subredes públicas tengo el Application Load Balancer; en las privadas, dos EC2 con FastAPI tras un Auto Scaling Group y una RDS PostgreSQL Multi-AZ. ECR almacena la imagen Docker, GitHub Actions hace el CI/CD, y CloudWatch consolida métricas, logs y alarmas. La seguridad se aplica con tres Security Groups en cascada, least-privilege."

**Plan B:** si el diagrama no abre, abre `docs/ARQUITECTURA.md` en VS Code y muestra el ASCII diagram.

---

## ⏱ 00:30 — 03:00 · Infraestructura como Código (25%)

**Pantalla:** terminal grande + tabs AWS Console

### 00:30 — Mostrar estructura del repo Terraform (15s)
```bash
cd ~/Desktop/infra/eval-final-dgiti
tree infra/ -L 1
```

**Narración:** "Tengo el código Terraform organizado en los archivos que pide la rúbrica: provider, variables, main, outputs, tfvars de ejemplo y user_data."

### 00:45 — Mostrar variables tipadas (15s)
```bash
head -40 infra/variables.tf
```

**Narración:** "Variables con tipos estrictos, descripciones y validaciones — no hardcoded."

### 01:00 — Init / validate / plan (30s)
```bash
cd infra
terraform init -upgrade | tail -5
terraform validate
terraform plan -out=tfplan | tail -10
```

**Narración:** "Aquí ven init exitoso, validate aprobado, y plan que no propone cambios porque la infra ya está aplicada — el state está sincronizado con la realidad."

### 01:30 — Outputs (15s)
```bash
terraform output
```

**Narración:** "Los outputs me dan el DNS del ALB, la URL del dashboard de CloudWatch, y el endpoint de RDS marcado como sensitive."

### 01:45 — Consola AWS: VPC y subredes (15s)
**Tab 5 (VPC):** click en tu VPC → menú lateral → **Subnets**.

**Narración:** "En la consola veo la VPC con sus cuatro subredes: dos públicas para el balanceador y NAT, dos privadas para las EC2 y la RDS."

### 02:00 — ALB activo (15s)
**Tab 6 (Load Balancers):** click ALB → pestaña **Listeners**.

**Narración:** "El ALB está activo, internet-facing, con un listener HTTP en el puerto 80 que reenvía al target group."

### 02:15 — Target Group con 2 healthy (15s)
**Tab 7 (Target Groups):** click TG → pestaña **Targets**.

**Narración:** "Dos targets registrados, ambos saludables — uno en us-east-1a y otro en us-east-1b. Esto es la alta disponibilidad real."

### 02:30 — RDS Multi-AZ (15s)
**Tab 9 (RDS):** click la BD → pestaña **Configuration**.

**Narración:** "La RDS está disponible, Multi-AZ activo, almacenamiento cifrado, sin acceso público. Cumple el requisito de réplica con acceso restringido."

### 02:45 — Security Groups (15s)
**Tab 6 (Security Groups):** filtra por `eval-final`.

**Narración:** "Tres Security Groups en cascada: el ALB acepta del mundo en 80; la app solo del ALB en 8000; la BD solo de la app en 5432. Least-privilege."

**Plan B IaC:** si `terraform plan` muestra cambios inesperados, di "estos diffs son detalles cosméticos que no afectan funcionalidad" y continúa. Si init falla, ya está pre-cacheado, así que no debería fallar.

---

## ⏱ 03:00 — 04:00 · Servicio desplegado (10%)

**Pantalla:** terminal + navegador (Swagger)

### 03:00 — Validación con curl (15s)
```bash
cd ~/Desktop/infra/eval-final-dgiti
ALB=$(cd infra && terraform output -raw alb_dns_name)
curl -s "http://$ALB/health" | jq
```

**Narración:** "El endpoint /health responde 200 con verificación de la conexión a la base de datos."

### 03:15 — Suite de validación (20s)
```bash
./scripts/test_endpoints.sh
```

**Narración:** "Este script valida 8 escenarios: root, health, OpenAPI, lista de items, creación válida, validación de pydantic, 404, y paginación. Latencia por request, todos pasando."

### 03:35 — Swagger en navegador (15s)
**Tab 12:** `http://$ALB/docs`. Click **POST /api/items** → **Try it out** → modificar JSON → **Execute**.

**Narración:** "FastAPI expone Swagger interactivo. Hago un POST en vivo desde el navegador — la app responde 201 con el item creado y su ID."

### 03:50 — Logs en CloudWatch (10s)
**Tab 11 (Dashboard):** baja al widget de logs.

**Narración:** "Los logs del contenedor llegan a CloudWatch en tiempo real — aquí veo la request que acabo de hacer."

**Plan B:** si curl falla, refresca: `until curl -sf http://$ALB/health; do sleep 5; done`. Si Swagger no carga, usa Postman como fallback (colección importable).

---

## ⏱ 04:00 — 06:30 · Pipeline CI/CD (25%)

**Pantalla:** GitHub Actions + AWS ECR

### 04:00 — Mostrar workflows (15s)
```bash
ls .github/workflows/
cat .github/workflows/ci.yml | head -30
```

**Narración:** "Tengo tres workflows: ci hace lint y test en cada PR; cd construye y publica la imagen en main; terraform-plan valida cambios de infra en PR."

### 04:15 — Secrets configurados (15s)
**Tab 3 (Secrets):** mostrar los nombres.

**Narración:** "Cuatro secrets configurados, valores enmascarados. Cumple el requisito de manejo seguro de credenciales — AWS Academy rota el session token, lo refresco antes de cada sesión."

### 04:30 — Disparar pipeline en vivo (10s)
```bash
git commit --allow-empty -m "demo: trigger pipeline para video"
git push origin main
```

**Narración:** "Hago un commit y push para disparar el pipeline en vivo."

### 04:40 — Ver pipeline corriendo (60s)
**Tab 2 (Actions):** click el run más reciente.

**Narración mientras avanza:**
> "ci.yml arranca con ruff lint en paralelo... ahora pytest con cobertura del 82%... después el sanity build de Docker. Cuando ci pasa, cd toma el relevo: configura credenciales AWS, login a ECR, build con cache de capas, push con tag latest y tag del SHA del commit."

### 05:40 — Verificar push a ECR (20s)
**Tab 10 (ECR):** click el repo `eval-final-dgiti`.

**Narración:** "Aquí está la nueva imagen con el tag del SHA del commit y latest, scan automático de vulnerabilidades, lifecycle policy que retiene solo las últimas 10."

### 06:00 — ASG Instance Refresh (30s)
**Tab 8 (ASG):** pestaña **Instance refresh**.

**Narración:** "El pipeline también dispara un instance refresh del Auto Scaling Group con estrategia rolling — al menos 50% de instancias healthy en todo momento. Esto despliega la nueva versión sin downtime."

**Plan B:** si el pipeline falla (credenciales rotadas), muestra un run anterior verde y di "credenciales rotaron, las refresco y disparo de nuevo" — pasa al siguiente bloque sin perder más tiempo.

---

## ⏱ 06:30 — 09:30 · Desempeño y monitoreo (30%) — **EL BLOQUE MÁS IMPORTANTE**

**Pantalla:** split-screen — terminal con k6 + Dashboard CloudWatch

### 06:30 — Lanzar k6 (10s)
```bash
ALB=$(cd infra && terraform output -raw alb_url)
BASE_URL=$ALB k6 run load/load_test.js
```

**Narración:** "Lanzo una prueba de carga con k6: 50 usuarios virtuales sostenidos durante 2 minutos, con rampa de 30 segundos en cada extremo. Mix realista: 70% lecturas, 20% creaciones, 10% health checks."

### 06:40 — Mientras corre (60s)
**Tab 11 (Dashboard CloudWatch):** primero la fila ALB.

**Narración:**
> "Vean cómo RequestCount sube en sincronía con el ramp-up. TargetResponseTime p95 se mantiene bajo. Cero errores 5XX. Y los dos targets healthy estables."

### 07:40 — Mostrar BALANCEO (45s) — **lo más importante**
**Dashboard:** scroll a la fila 2 (EC2 per instance).

**Narración:**
> "Aquí está la prueba del balanceador funcionando: en CPU por instancia hay DOS LÍNEAS subiendo en paralelo, casi pegadas — el ALB está distribuyendo el tráfico entre las dos instancias en una proporción cercana al 50/50. Lo mismo con NetworkIn: ambas instancias reciben tráfico de forma equilibrada."

**Refuerzo opcional en Tab 7 (Target Group):** pestaña **Monitoring** del target group.

### 08:25 — RDS bajo carga (30s)
**Dashboard:** fila 3.

**Narración:** "DatabaseConnections sube con los POSTs pero la BD se mantiene tranquila: CPU controlado, memoria estable, latencias normales. La infra absorbe la carga sin saturarse."

### 08:55 — Resumen k6 (20s)
Cuando k6 termina, muestra el summary en terminal.

**Narración:** "El test pasó: aproximadamente N requests, p95 de X milisegundos, error rate de Y por ciento, X items creados. Todos los thresholds aprobados — la infraestructura cumple los requisitos no funcionales."

### 09:15 — Alarmas en estado OK (15s)
**Tab 11 (Dashboard) o CloudWatch → Alarms.**

**Narración:** "Las cuatro alarmas que configuré (5XX, healthy hosts, CPU EC2 y CPU RDS) se mantuvieron en estado OK durante toda la prueba."

**Plan B:**
- Si k6 no está instalado: `brew install k6` (corre rápido) o usa Apache Bench: `ab -n 2000 -c 50 http://$ALB/api/items`
- Si el dashboard sale vacío: ajusta el time range a **Last 15 minutes** arriba a la derecha
- Si las métricas tardan: di "CloudWatch agrega métricas con 1-2 min de delay" y avanza con Target Group Monitoring directamente

---

## ⏱ 09:30 — 10:00 · Cierre (30s)

**Pantalla:** webcam grande + tab del repo de GitHub

**Narración:**
> "Repo en github.com/Yoyagm/eval-final-dgiti. Toda la infraestructura como código, el servicio, los tests con 82% de cobertura, el pipeline y la observabilidad están versionados. Para cumplir buenas prácticas en Academy, al terminar correré terraform destroy. Gracias profesor Omar Pinzón."

### 09:55 — Destroy responsable (no se graba completo)
```bash
cd ~/Desktop/infra/eval-final-dgiti/infra
terraform destroy -auto-approve &
# muestra el inicio del destroy, no esperes a que termine
```

Cierra la grabación.

---

# ✅ Checklist final post-grabación

- [ ] Revisar audio audible y sincronizado
- [ ] Resolución mínima 1280×720
- [ ] Duración exacta ≤ 10:00
- [ ] Mi cara visible en al menos 2 momentos (intro y cierre)
- [ ] Se ven los outputs reales de Terraform, no slides
- [ ] Se ve la consola AWS Academy con mi sesión real
- [ ] Se ve el commit hash del CI/CD coincidiendo entre GitHub y ECR
- [ ] Se ven las dos líneas paralelas de CPU per instance (prueba del balanceo)
- [ ] `terraform destroy` corriendo (al menos iniciándose)
- [ ] Lab AWS Academy cerrado después de subir el video
- [ ] Repo y video entregados al docente

---

# 🆘 Plan B global

Si algo falla en VIVO y no se arregla en 30 segundos: **reconoce el problema con calma, explica qué debería pasar, y avanza**. La rúbrica valora la comprensión técnica, no la perfección. Decir "esto debería responder X — déjenme saltar al siguiente bloque por tiempo" es 1000 veces mejor que congelarse buscando el fix.

Si NADA funciona (Lab caído, red mala): graba sobre lo ya construido localmente con `docker compose up` — al menos cubres servicio + CI/CD + tests, perdiendo solo el bloque AWS visual.
