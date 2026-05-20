# Observabilidad y Desempeño — eval-final-dgiti

Documento técnico de cómo está instrumentada la infraestructura, qué métricas se observan, y cómo presentar la evidencia en el video (peso rúbrica: **30%**).

---

## 1. Filosofía: Golden Signals + RED + USE

Aplico las tres metodologías estándar de la industria:

| Capa | Metodología | Métricas observadas |
|---|---|---|
| Servicio HTTP (ALB) | **RED** (Rate, Errors, Duration) | RequestCount, HTTPCode_*, TargetResponseTime |
| Recursos (EC2/RDS) | **USE** (Utilization, Saturation, Errors) | CPUUtilization, NetworkIn/Out, DatabaseConnections, FreeableMemory |
| Disponibilidad | **Golden Signal** | HealthyHostCount, UnHealthyHostCount |

---

## 2. Componentes desplegados por Terraform

### 2.1 CloudWatch Log Group
- **Nombre:** `/eval-final-dgiti/app`
- **Retención:** 7 días
- **Fuente:** `amazon-cloudwatch-agent` en cada EC2 captura `/var/lib/docker/containers/*/*.log`
- **Streams:** `{instance_id}/docker` y `{instance_id}/bootstrap`

### 2.2 Alarmas CloudWatch (4)

| Alarma | Métrica | Umbral | Para qué |
|---|---|---|---|
| `eval-final-dgiti-alb-5xx-high` | `HTTPCode_Target_5XX_Count` | > 5 en 1 min | Detecta errores del servidor |
| `eval-final-dgiti-unhealthy-hosts` | `HealthyHostCount` | < 1 por 2 min | Detecta caída total del servicio |
| `eval-final-dgiti-ec2-cpu-high` | `CPUUtilization` (ASG avg) | > 75% por 2 min | Detecta saturación de cómputo |
| `eval-final-dgiti-rds-cpu-high` | `CPUUtilization` RDS | > 80% por 2 min | Detecta saturación de BD |

### 2.3 Dashboard CloudWatch `eval-final-dgiti-overview`

13 widgets organizados en 4 filas (24 cols de ancho cada fila):

```
┌──────────────────────────────────────────────────────────────────────┐
│ ALB Requests │ ALB Latency │ ALB 4XX/5XX │ ALB Healthy/Unhealthy    │ ← golden signals
├──────────────────────────────────────────────────────────────────────┤
│ EC2 CPU per instance │ EC2 NetworkIn per │ EC2 NetworkOut per       │ ← balanceo visible
├──────────────────────────────────────────────────────────────────────┤
│ RDS CPU │ RDS Connections │ RDS FreeableMem │ RDS Read/Write Latency │ ← BD
├──────────────────────────────────────────────────────────────────────┤
│ App logs (CloudWatch Logs Insights) — últimas 50 líneas              │ ← debug
└──────────────────────────────────────────────────────────────────────┘
```

**URL directa:** queda en el output `cloudwatch_dashboard_url` de Terraform.

### 2.4 Prueba de carga k6

`load/load_test.js` — 3 minutos totales:
- 30 s ramp 0→50 VUs
- 2 min sostener 50 VUs
- 30 s ramp 50→0
- Mix 70/20/10 (GET items / POST items / health)

Thresholds que **fallan** el test:
- `http_req_duration` p95 ≥ 1500 ms
- `http_req_failed` ≥ 5%
- Latencias específicas por endpoint

---

## 3. Cómo evidenciar todo en el video (≈3 min de los 10)

### Setup previo a grabar
1. `terraform apply` exitoso y app respondiendo
2. `./scripts/seed_data.sh` ya corrido (BD con items reales)
3. `k6` instalado: `brew install k6`
4. 3 tabs abiertas en el navegador:
   - **Tab A:** Dashboard CloudWatch (`terraform output -raw cloudwatch_dashboard_url`)
   - **Tab B:** EC2 → Auto Scaling Groups → eval-final-dgiti-asg → **Instance management**
   - **Tab C:** EC2 → Target Groups → eval-final-dgiti-tg → **Targets**
5. Terminal dividido en 2 paneles (uno para k6, otro para SSH/curl si se necesita)

### Guion del bloque de monitoreo (~3 min)

```
[0:00]  "Voy a ejecutar una prueba de carga de 3 minutos contra el ALB
         con 50 usuarios virtuales sostenidos."
         
         → Comando en terminal:
           BASE_URL=$(cd infra && terraform output -raw alb_url) \
             k6 run load/load_test.js

[0:15]  Ramp-up en curso, abrir Tab A (Dashboard):
         "Vean cómo RequestCount empieza a subir en el ALB"
         "El TargetResponseTime p95 se mantiene bajo"

[0:45]  Sostén carga, mostrar widgets:
         "Aquí está la evidencia del balanceo: en EC2 CPU per instance
          vemos DOS LÍNEAS que suben en paralelo — el ALB está
          distribuyendo el tráfico entre las dos instancias"
         
         Cambiar a Tab C (Target Group → Targets):
         "Ambos targets están healthy y reciben tráfico equilibrado"

[1:30]  Mid-test, mostrar logs:
         Tab A bajar al widget de logs:
         "Aquí veo las requests en tiempo real desde los contenedores"

[2:00]  (Opcional dramatizar HA):
         Tab B, terminar una instancia manualmente:
         "Voy a terminar una instancia mientras k6 sigue corriendo"
         → ASG detecta unhealthy en CloudWatch
         → ALB redirige 100% del tráfico a la instancia restante
         → k6 sigue sin errores (o muy pocos)
         → ASG lanza una nueva instancia automáticamente

[2:30]  k6 termina:
         Leer summary en terminal:
         "Resultado: X requests, p95 = Y ms, error rate = Z%"
         "Todos los thresholds aprobados"
         
         Volver a Tab A y mostrar el patrón completo:
         "Las métricas se mantuvieron dentro de los SLO durante toda
          la prueba. CPU pico = N%, conexiones a RDS pico = M"
```

### Frase técnica de cierre (para el video)

> "La arquitectura soportó 50 usuarios virtuales sostenidos durante 2 minutos con un balanceo casi 50/50 entre las dos instancias EC2, latencia p95 de X ms y tasa de error del Y%. CloudWatch capturó toda la telemetría sin alarmas activas, evidenciando que la infraestructura cumple los requisitos no funcionales de disponibilidad y rendimiento."

---

## 4. Conexión rúbrica ↔ evidencia

| Requisito de la rúbrica F6 (30%) | Cómo se demuestra |
|---|---|
| Ejecuta pruebas de carga correctamente | `k6 run load/load_test.js` en pantalla |
| Mide tiempo de respuesta | Trends `http_req_duration` p50/p95/p99 |
| Mide usuarios concurrentes | `vus_max=50` en el summary |
| Mide % de errores | `http_req_failed` + métrica `errors` |
| Evidencia saturación / comportamiento bajo carga | CPU EC2 + RDS CPU + Connections crecen |
| Funcionamiento del balanceador | **CPU EC2 per instance** muestra 2 líneas paralelas |
| Métricas en CloudWatch | Dashboard `eval-final-dgiti-overview` |
| Relación métricas ↔ infraestructura | Narrativa explicada arriba |

---

## 5. Troubleshooting (qué hacer si algo falla en vivo)

| Síntoma | Causa probable | Fix rápido |
|---|---|---|
| k6 no se conecta al ALB | DNS no resuelve aún | Esperar 30-60s post-apply |
| 5XX masivos en /api/items | RDS aún arrancando | Esperar `multi_az = available` |
| 1 instancia healthy de 2 | Imagen Docker no en ECR aún | `./scripts/build_and_push.sh` + esperar pull |
| Métricas no aparecen | CloudWatch tarda ~2 min en agregar | Refrescar el dashboard |
| k6 timeout | `--http-debug` para ver request | Verificar SG del ALB |
| Dashboard vacío | Período muy reciente | Ajustar time range a "last 15m" |
