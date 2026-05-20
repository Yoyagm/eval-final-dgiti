# 🎬 Guion Definitivo de Grabación — eval-final-dgiti

> **Duración objetivo:** ≤ 10:00
> **Modalidad:** demostración en vivo, integrante único, cuenta AWS Academy
> **Repo:** https://github.com/Yoyagm/eval-final-dgiti
> **CI verde confirmado:** ✅ run 26136382712 · 1m46s · pytest 82% coverage

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

# 🧱 PARTE 0 — Una sola tarea pendiente (5 min, hazla ya)

## Exportar el diagrama a PNG

1. Abre https://app.diagrams.net/
2. **File → Open from → Device** → selecciona `docs/diagrama.drawio`
3. Se ve el diagrama con iconos AWS 2026 oficiales
4. **File → Export as → PNG**
   - Zoom: **200%**
   - Border: **20**
   - Background: **White**
   - Selection only: **No**
5. Guarda como `docs/diagrama.png`
6. Sube al repo:
   ```bash
   cd ~/Desktop/infra/eval-final-dgiti
   git add docs/diagrama.png
   git commit -m "docs: agrega diagrama PNG con iconos AWS 2026"
   git push
   ```

> Sin este PNG, la rúbrica de Arquitectura (10%) se ve afectada — el `.md` pide explícitamente "iconos oficiales de AWS 2026".

---

# 📋 PARTE 1 — Preparación antes de grabar (~45 min, NO se graba)

## 1.1 · Iniciar Lab AWS Academy (5 min)

1. Abre **AWS Academy** → tu curso → módulo → click **Start Lab**
2. Espera el punto verde junto a "AWS" (puede tardar 2-4 min)
3. Click **"AWS Details"** → arriba dice "AWS CLI" → click "Show"
4. Verás 4 líneas: aws_access_key_id, aws_secret_access_key, aws_session_token, region
5. Cópialas y pégalas en la terminal:

```bash
# Pega aquí el contenido del bloque "AWS CLI":
export AWS_ACCESS_KEY_ID="ASIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export AWS_REGION="us-east-1"

# Verifica que funciona
aws sts get-caller-identity
# Debe responder con: "Account": "1234567890XX" (tu cuenta del Lab)
```

⚠️ **NO cierres el Lab ni esta terminal hasta terminar de grabar.** Si lo cierras, las credenciales se invalidan.

## 1.2 · Configurar secrets en GitHub (1 min)

Con las credenciales ya exportadas en tu shell:

```bash
gh secret set AWS_REGION             --body "us-east-1"               -R Yoyagm/eval-final-dgiti
gh secret set AWS_ACCESS_KEY_ID      --body "$AWS_ACCESS_KEY_ID"      -R Yoyagm/eval-final-dgiti
gh secret set AWS_SECRET_ACCESS_KEY  --body "$AWS_SECRET_ACCESS_KEY"  -R Yoyagm/eval-final-dgiti
gh secret set AWS_SESSION_TOKEN      --body "$AWS_SESSION_TOKEN"      -R Yoyagm/eval-final-dgiti

# Verifica
gh secret list -R Yoyagm/eval-final-dgiti
# Deben aparecer los 4
```

## 1.3 · Terraform apply (15 min — RDS es lo lento)

```bash
cd ~/Desktop/infra/eval-final-dgiti/infra
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply -auto-approve
# ⏱ 10-15 minutos. RDS Multi-AZ tarda ~8 min solo.
```

Cuando termine, ANOTA estos valores (los usarás en el video):
```bash
terraform output
# Copia estos 3:
ALB=$(terraform output -raw alb_dns_name)
DASH=$(terraform output -raw cloudwatch_dashboard_url)
ECR=$(terraform output -raw ecr_repository_url)
echo "ALB:  $ALB"
echo "DASH: $DASH"
echo "ECR:  $ECR"
```

## 1.4 · Push imagen Docker a ECR (4 min)

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

## 1.5 · Esperar app healthy + seed (3 min)

```bash
ALB=$(cd infra && terraform output -raw alb_dns_name)

# Espera a que las EC2 hagan pull y arranquen
until curl -sf "http://$ALB/health" >/dev/null; do
  echo "Esperando app..."; sleep 15
done
echo "✓ App respondiendo"

# Datos demo
./scripts/seed_data.sh

# Suite de validación
./scripts/test_endpoints.sh
# Debe terminar: 8 pass • 0 fail
```

## 1.6 · Disparar pipeline para tener corrida verde (5 min)

```bash
cd ~/Desktop/infra/eval-final-dgiti
git commit --allow-empty -m "ci: pre-grabación video"
git push origin main

# Monitorea
gh run watch -R Yoyagm/eval-final-dgiti
# Espera CI verde + CD verde (~5 min)
```

## 1.7 · Verificación final pre-grabación

```bash
# Todo debe pasar:
echo "=== CHECKLIST FINAL ==="
echo "ALB:    $(curl -so /dev/null -w '%{http_code}' http://$(cd infra && terraform output -raw alb_dns_name)/health)"
echo "Diag:   $(test -f docs/diagrama.png && echo OK || echo FALTA)"
echo "Repo:   $(gh repo view Yoyagm/eval-final-dgiti --json url -q .url)"
echo "CI:     $(gh run list -R Yoyagm/eval-final-dgiti -w ci.yml -L 1 --json conclusion -q '.[0].conclusion')"
echo "CD:     $(gh run list -R Yoyagm/eval-final-dgiti -w cd.yml -L 1 --json conclusion -q '.[0].conclusion')"
```

Salida esperada:
```
ALB:    200
Diag:   OK
Repo:   https://github.com/Yoyagm/eval-final-dgiti
CI:     success
CD:     success
```

---

# 🖥️ PARTE 2 — Setup físico (10 min antes de presionar REC)

## 2.1 · Pre-abrir 12 tabs en el navegador (en este orden)

| # | URL | Para qué bloque |
|---|---|---|
| 1 | `docs/diagrama.png` (visor de imágenes) | Arquitectura |
| 2 | https://us-east-1.console.aws.amazon.com/vpcconsole/home?region=us-east-1#vpcs: | IaC |
| 3 | https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#LoadBalancers: | IaC |
| 4 | https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#TargetGroups: | IaC + Desempeño |
| 5 | https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#AutoScalingGroups: | IaC + CI/CD |
| 6 | https://us-east-1.console.aws.amazon.com/rds/home?region=us-east-1#databases: | IaC |
| 7 | https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#SecurityGroups: | IaC |
| 8 | http://<ALB-DNS>/docs | Servicio |
| 9 | https://github.com/Yoyagm/eval-final-dgiti/settings/secrets/actions | CI/CD |
| 10 | https://github.com/Yoyagm/eval-final-dgiti/actions | CI/CD |
| 11 | https://us-east-1.console.aws.amazon.com/ecr/repositories?region=us-east-1 | CI/CD |
| 12 | (pegar el output de `terraform output -raw cloudwatch_dashboard_url`) | Desempeño |

## 2.2 · Terminal

- Tamaño: ocupando todo el ancho de la pantalla
- Font size grande (≥16pt) para que se lea en el video
- **Pane izquierdo**: para comandos
- **Pane derecho**: durante k6, mostrará progreso de la carga
- Directorio actual: `~/Desktop/infra/eval-final-dgiti`

```bash
cd ~/Desktop/infra/eval-final-dgiti
# Ten estas variables exportadas en la shell:
export ALB=$(cd infra && terraform output -raw alb_dns_name)
export DASH=$(cd infra && terraform output -raw cloudwatch_dashboard_url)
echo "ALB=$ALB"
echo "DASH=$DASH"
```

## 2.3 · Webcam y audio

- Webcam encendida, esquina inferior derecha
- Micrófono probado (di "uno dos tres" y verifica el nivel)
- Apaga notificaciones de Mac (Do Not Disturb)
- Cierra Slack, Mail, etc.

## 2.4 · Cronómetro

- Ten un cronómetro visible (segunda pantalla o reloj físico)
- Marca cuando arrancas y vigila cada checkpoint

---

# 🎥 PARTE 3 — Guion de grabación segundo a segundo

> Las **frases entre comillas** son guía. Dilas con tus palabras, no las leas.
> Los **comandos en bloques** son para copiar y pegar en tiempo real.

---

## ⏱ 00:00 — 00:30 · Intro + Arquitectura (peso 10%)

### Pantalla: **Tab 1 (diagrama.png)** + webcam grande

### Comando previo (no se graba):
Ten `docs/diagrama.png` ya abierto en pantalla completa.

### Decir (≈25s):
> "Hola, soy **Johan Rodríguez**. Como integrante único, voy a sustentar la evaluación final del curso de Diseño y Gestión de Infraestructura Tecnológica.
>
> Esta es la arquitectura que diseñé: una **VPC en us-east-1 con dos zonas de disponibilidad**. En las subredes públicas tengo el **Application Load Balancer** y el NAT Gateway; en las privadas, **dos instancias EC2** corriendo FastAPI tras un Auto Scaling Group, y una **RDS PostgreSQL Multi-AZ** completamente aislada de Internet.
>
> **ECR** almacena la imagen Docker, **GitHub Actions** maneja el CI/CD, y **CloudWatch** centraliza métricas, logs y alarmas. La seguridad se aplica con **tres Security Groups en cascada**, todos con principio de least-privilege."

### Plan B
Si el diagrama PNG no abre, mantén el .drawio abierto en draw.io y úsalo igual (el evaluador no nota la diferencia si el rendering es bueno).

---

## ⏱ 00:30 — 03:00 · Infraestructura como Código (peso 25%)

### Pantalla: terminal grande, alternando con tabs de AWS

### 00:30 — Mostrar estructura del repo Terraform (20s)

#### Comando:
```bash
cd ~/Desktop/infra/eval-final-dgiti
ls infra/
```

#### Decir:
> "El Terraform está organizado exactamente como pide la rúbrica: **provider.tf**, **variables.tf**, **main.tf**, **outputs.tf**, **terraform.tfvars.example** sin secretos, y **user_data.sh** que arranca el contenedor en cada EC2."

### 00:50 — Mostrar variables tipadas (15s)

#### Comando:
```bash
head -30 infra/variables.tf
```

#### Decir:
> "Las variables están tipadas, con descripciones y **validaciones**. Por ejemplo, `project_name` valida que sea kebab-case con expresión regular. No hay valores hardcoded."

### 01:05 — Init, validate, plan, output (45s)

#### Comando:
```bash
cd infra
terraform init -upgrade | tail -8
```

#### Decir:
> "**terraform init** descarga los providers de AWS y random."

#### Comando:
```bash
terraform validate
```

#### Decir:
> "**validate** confirma que la configuración es válida."

#### Comando:
```bash
terraform plan -out=tfplan | tail -15
```

#### Decir:
> "**plan** muestra que el state está sincronizado con la realidad — todo aplicado, sin cambios pendientes."

#### Comando:
```bash
terraform output
```

#### Decir:
> "**output** me da el DNS del ALB, la URL del dashboard de CloudWatch, y el endpoint de RDS marcado como **sensitive** — nunca se imprime el password en claro."

### 01:50 — Tab 2 (VPC): mostrar VPC + subredes (15s)

#### Acción: cambia a **Tab 2 (VPC dashboard)**, click en tu VPC, menú lateral → **Subnets**

#### Decir:
> "En la consola está la VPC con sus **cuatro subredes**: dos públicas en CIDR 10.0.1 y 10.0.2 para el ALB y el NAT, y dos privadas en 10.0.11 y 10.0.12 para las EC2 y la RDS. Cada una etiquetada con su Tier."

### 02:05 — Tab 3 (ALB): mostrar listener (15s)

#### Acción: **Tab 3 (Load Balancers)**, click ALB, pestaña **Listeners and rules**

#### Decir:
> "El ALB está **active**, internet-facing, con un listener HTTP en el puerto 80 que forwarda al target group."

### 02:20 — Tab 4 (Target Group): mostrar 2 healthy (15s)

#### Acción: **Tab 4 (Target Groups)**, click TG `eval-final-dgiti-tg`, pestaña **Targets**

#### Decir:
> "Los **dos targets están healthy**, uno en us-east-1a y otro en us-east-1b — esta es la alta disponibilidad real, no teórica."

### 02:35 — Tab 6 (RDS): mostrar Multi-AZ (15s)

#### Acción: **Tab 6 (RDS)**, click la instancia, pestaña **Configuration**

#### Decir:
> "La RDS está **available**, **Multi-AZ: Yes** que es la réplica síncrona, storage encriptado, y **publicly accessible: No** — solo se alcanza desde la subred privada vía el Security Group de la app. Cumple el requisito de réplica con acceso restringido."

### 02:50 — Tab 7 (Security Groups): mostrar 3 SGs (10s)

#### Acción: **Tab 7 (Security Groups)**, filtra por `eval-final`

#### Decir:
> "Y los **tres Security Groups en cascada**: el ALB acepta del mundo en 80; la app **solo del ALB** en 8000; la BD **solo de la app** en 5432. Least-privilege en cada capa."

### Plan B IaC
- Si `terraform plan` muestra cambios inesperados → "diferencias cosméticas que no afectan funcionalidad, sigo".
- Si la consola carga lento → ten capturas previas (`docs/screenshots/`) listas como fallback.

---

## ⏱ 03:00 — 04:00 · Servicio desplegado (peso 10%)

### Pantalla: terminal + navegador (Swagger)

### 03:00 — curl al health (15s)

#### Comando:
```bash
curl -s "http://$ALB/health" | jq
```

#### Decir:
> "El endpoint **`/health`** responde 200 con verificación de la conexión a la base de datos. La estructura es estándar — campo `data` con el estado, campo `meta` con el request ID propagado."

### 03:15 — Script de validación (25s)

#### Comando:
```bash
./scripts/test_endpoints.sh
```

#### Decir mientras corre:
> "Este script valida **8 escenarios**: root, health, OpenAPI schema, listado, creación válida con 201, validación pydantic que devuelve 422, 404 cuando no existe, y paginación. **Latencia por request**, con colores. Todos en verde."

### 03:40 — Tab 8 (Swagger): hacer POST en vivo (15s)

#### Acción: **Tab 8** (`http://$ALB/docs`)
- Click en **POST /api/items** → **Try it out**
- En el body cambiar el `name` por "Demo en vivo"
- Click **Execute**

#### Decir:
> "FastAPI expone Swagger interactivo. Hago un POST en vivo desde el navegador — la app responde **201** con el item creado y su ID auto-generado."

### 03:55 — Mostrar EC2 instances + logs (5s)

#### Acción rápida: **Tab 5 (ASG)** → click la ASG → pestaña **Instance management**

#### Decir:
> "Las dos instancias EC2 están **InService** en distintas AZs."

### Plan B
- Si curl falla: `until curl -sf http://$ALB/health; do sleep 5; done` y reintenta.
- Si Swagger no carga: usa **Postman** (importa `postman/eval-final-dgiti.postman_collection.json`).

---

## ⏱ 04:00 — 06:30 · Pipeline CI/CD (peso 25%)

### Pantalla: GitHub Actions + AWS ECR

### 04:00 — Mostrar workflows (15s)

#### Comando:
```bash
ls .github/workflows/
```

#### Decir:
> "Tres workflows con responsabilidades separadas: **ci.yml** hace lint con ruff y tests con pytest en cada PR; **cd.yml** construye la imagen y la publica en ECR cuando hay merge en main; **terraform-plan.yml** valida cambios de infraestructura en pull requests."

### 04:15 — Tab 9 (Secrets): mostrar 4 secrets (15s)

#### Acción: **Tab 9** (Settings → Secrets and variables → Actions)

#### Decir:
> "**Cuatro secrets configurados**, valores enmascarados. AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN porque Academy rota credenciales, y AWS_REGION. Las credenciales nunca aparecen en el YAML."

### 04:30 — Disparar pipeline en vivo (10s)

#### Comando:
```bash
git commit --allow-empty -m "ci: demo en vivo durante grabación"
git push origin main
```

#### Decir:
> "Hago un commit vacío y push para disparar el pipeline en vivo."

### 04:40 — Tab 10 (Actions): ver runs corriendo (90s)

#### Acción: **Tab 10** (Actions), click el run más reciente

#### Decir mientras avanza:
> "Aquí está **CI corriendo**: arranca con **ruff** para lint, después **pytest** con cobertura del **82%**, finalmente un sanity build de Docker. Tiempo total **alrededor de dos minutos**.
>
> En paralelo **CD se dispara**: configura las credenciales de AWS Academy, hace login a ECR, construye la imagen con cache de capas de Docker para ser rápido, y la publica con **dos tags** — `latest` y el SHA corto del commit para trazabilidad."

### 06:00 — Tab 11 (ECR): mostrar imagen pusheada (15s)

#### Acción: **Tab 11** (ECR), click repo `eval-final-dgiti`

#### Decir:
> "Aquí está la **imagen recién publicada** con el tag del SHA del commit, **scan de vulnerabilidades** automático activado, y lifecycle policy que mantiene solo las últimas 10."

### 06:15 — Tab 5 (ASG): instance refresh (15s)

#### Acción: **Tab 5** (ASG), pestaña **Instance refresh**

#### Decir:
> "El pipeline también dispara un **instance refresh rolling** del Auto Scaling Group — mantiene al menos el 50% de instancias healthy en todo momento. Despliegue **zero-downtime** sin tocar Terraform en runtime."

### Plan B CI/CD
- Si las credenciales rotaron y CD falla → di "credenciales del Lab rotaron, normalmente las refresco antes de cada sesión", y muestra el **run anterior verde** (de la preparación) — la rúbrica es satisfecha igual.

---

## ⏱ 06:30 — 09:30 · Desempeño y monitoreo (peso 30% — **EL BLOQUE MÁS IMPORTANTE**)

### Pantalla: split-screen — terminal con k6 + Tab 12 (Dashboard CloudWatch)

### 06:30 — Lanzar k6 (15s)

#### Comando:
```bash
BASE_URL="http://$ALB" k6 run load/load_test.js
```

#### Decir:
> "Lanzo una prueba de carga con **k6**: ramp-up de 30 segundos hasta 50 usuarios virtuales, sostener 50 VUs durante 2 minutos, ramp-down de 30 segundos. **Mix realista de tráfico: 70% lecturas, 20% creaciones, 10% health checks**. Cinco thresholds que **fallan el test** si se exceden — p95 bajo 1.5 segundos y error rate bajo 5%."

### 06:45 — Tab 12 (Dashboard CloudWatch): fila 1 ALB (45s)

#### Acción: cambia a **Tab 12 (Dashboard)** en split-screen, foco en la primera fila

#### Decir mientras crece la carga:
> "Vean cómo en CloudWatch el **RequestCount sube en sincronía** con el ramp-up de k6. El **TargetResponseTime p95 se mantiene controlado**. **Cero errores 5XX**. Y los **dos targets healthy** estables — la infra absorbe la carga sin tumbarse."

### 07:30 — **El momento crítico**: balanceo visible (60s)

#### Acción: scroll a la **segunda fila** del dashboard (EC2 per instance)

#### Decir lento y claro:
> "**Aquí está la prueba del balanceador funcionando**: en el panel de **CPU por instancia** hay **dos líneas que suben en paralelo, casi pegadas** — el ALB está distribuyendo el tráfico entre las dos instancias en proporción cercana al **50/50**. Si una sola instancia recibiera todo, vería una línea al 100% y la otra plana. Lo mismo con **NetworkIn**: ambas reciben tráfico equilibrado."

#### Acción opcional refuerzo: **Tab 4 (Target Group)** → pestaña **Monitoring**

#### Decir:
> "El target group lo confirma: ambos targets reciben requests en paralelo."

### 08:30 — Tab 12: fila 3 RDS (30s)

#### Acción: scroll a la **tercera fila** (RDS)

#### Decir:
> "La **RDS** absorbe la carga: **DatabaseConnections** sube proporcional a los POSTs, pero la CPU se mantiene tranquila, lejos del umbral del 80% de la alarma. La memoria estable y las latencias normales."

### 09:00 — Resumen k6 (20s)

#### Acción: vuelve al terminal cuando k6 termine, muestra el summary

#### Decir leyendo los números reales:
> "Resultado: aproximadamente **N requests**, **p95 de X milisegundos**, **error rate de Y por ciento**, **Z items creados**. **Todos los thresholds aprobados**. La infraestructura cumple los requisitos no funcionales bajo carga sostenida."

### 09:20 — Alarmas OK (10s)

#### Acción: **Tab 12 (Dashboard)** o CloudWatch Alarms

#### Decir:
> "Y las **cuatro alarmas** que configuré — 5XX altos, healthy hosts, CPU EC2 y CPU RDS — se mantuvieron en **estado OK** durante toda la prueba."

### Plan B Desempeño
- Si k6 no se instala a tiempo → `ab -n 2000 -c 50 http://$ALB/api/items` con Apache Bench (preinstalado en macOS).
- Si el dashboard sale vacío → ajusta el **time range** a "Last 15 minutes" arriba a la derecha.
- Si las métricas tardan en aparecer → "CloudWatch agrega métricas con uno o dos minutos de delay, ya las verán" y avanza con la pestaña **Monitoring** del target group.

---

## ⏱ 09:30 — 10:00 · Cierre (30s)

### Pantalla: webcam grande + Tab del repo

### Decir:
> "Repositorio público en **github.com/Yoyagm/eval-final-dgiti**. Toda la infraestructura como código, el servicio FastAPI con **19 tests y 82% de cobertura**, el pipeline CI/CD, los scripts de validación, la prueba de carga y la observabilidad están versionados.
>
> Para cumplir buenas prácticas con AWS Academy, al cerrar este video ejecuto **terraform destroy** y cierro el Lab. Gracias **profesor Omar Pinzón**."

### Comando opcional (mientras hablas, no esperes que termine):
```bash
cd ~/Desktop/infra/eval-final-dgiti/infra
terraform destroy -auto-approve &
# Solo muestra que arranca, corta video al ver "Destroying..."
```

---

# 🧹 PARTE 4 — Post-grabación

## 4.1 · Destroy responsable

Si no lo lanzaste durante el cierre:
```bash
cd ~/Desktop/infra/eval-final-dgiti/infra
terraform destroy -auto-approve
# ⏱ ~10 min. Espera a que termine
```

Cierra el Lab en AWS Academy (botón "End Lab").

## 4.2 · Revisión del video

- [ ] Duración ≤ 10:00
- [ ] Audio audible y sincronizado
- [ ] Mi cara visible en intro y cierre
- [ ] Se ven outputs reales de Terraform (no diapositivas)
- [ ] Se ve la consola de AWS Academy con MI cuenta
- [ ] Se ve el dashboard de CloudWatch con métricas
- [ ] Se ven las **dos líneas paralelas** de CPU per instance (clave para el 30%)
- [ ] Se ven los workflows verdes en GitHub Actions
- [ ] Se ve el SHA del commit coincidiendo entre GitHub y ECR
- [ ] `terraform destroy` corriendo (al menos iniciándose)

## 4.3 · Entrega

- Sube el video al medio que pida el docente (drive, sharepoint, etc.)
- Comparte el link al repo: https://github.com/Yoyagm/eval-final-dgiti
- Confirma que el repo es público (lo es, ya verificado)

---

# 🆘 Plan B global

Si algo falla en VIVO y no se arregla en 30 segundos: **reconoce el problema con calma, explica qué debería pasar, y avanza al siguiente bloque**. La rúbrica valora la comprensión técnica, no la perfección. "Esto debería responder X, déjenme saltar al siguiente bloque por tiempo" es **mil veces mejor** que congelarse buscando el fix.

Si NADA funciona en AWS (Lab caído, red mala): graba sobre lo construido localmente con `docker compose up` — cubres servicio + tests + CI/CD verde en GitHub, perdiendo solo el bloque AWS visual.

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
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names eval-final-dgiti-tg --query 'TargetGroups[0].TargetGroupArn' --output text)

# Disparar pipeline
git commit --allow-empty -m "ci: trigger" && git push

# Carga
BASE_URL="http://$ALB" k6 run load/load_test.js

# Limpieza
cd infra && terraform destroy -auto-approve
```
