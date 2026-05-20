# Pruebas de carga — k6

Suite de carga para evidenciar el balanceo del ALB y la salud del servicio bajo presión.

## Instalación

```bash
# macOS
brew install k6

# Verificar
k6 version
```

## Ejecutar

```bash
# Auto-detecta el ALB desde terraform output
BASE_URL=$(cd infra && terraform output -raw alb_url) k6 run load/load_test.js

# O explícito
BASE_URL=http://eval-final-dgiti-alb-XXXX.us-east-1.elb.amazonaws.com k6 run load/load_test.js

# Local (contra docker-compose)
BASE_URL=http://localhost:8000 k6 run load/load_test.js
```

## Perfil del test

| Stage | Duración | VUs |
|---|---|---|
| Ramp-up | 30 s | 0 → 50 |
| Sostener | 2 min | 50 |
| Ramp-down | 30 s | 50 → 0 |
| **Total** | **3 min** | — |

Mix de tráfico:
- 70% `GET /api/items`
- 20% `POST /api/items`
- 10% `GET /health`

## Thresholds (fallan el test si se exceden)

| Métrica | Umbral |
|---|---|
| `http_req_duration` p95 | < 1500 ms |
| `http_req_failed` | < 5% |
| `latency_health_ms` p95 | < 800 ms |
| `latency_list_ms` p95 | < 1200 ms |
| `latency_create_ms` p95 | < 2000 ms |

## Salidas

- **Tiempo real** en terminal con métricas progresivas.
- **Summary** al final con tabla custom (latencias p50/p95/p99, error rate, items creados).
- **JSON** completo en `load/results/summary.json` (apto para gráficos posteriores).

## Cómo leer la evidencia en CloudWatch durante la prueba

Mientras k6 corre, abrir el dashboard `eval-final-dgiti-overview` y observar:

| Widget CloudWatch | Qué confirmar |
|---|---|
| **ALB · RequestCount** | Sube de ~0 a ~30-50 req/min en sync con el ramp-up |
| **ALB · TargetResponseTime p95** | Se mantiene por debajo del threshold |
| **ALB · 4XX vs 5XX** | 5XX en cero (idealmente). 4XX puede aparecer si hay validaciones |
| **ALB · Healthy hosts** | Constante en 2 — la app responde sin tumbar instancias |
| **EC2 · CPU por instancia** | **2 líneas que suben en paralelo** — esto **es** la prueba del balanceo |
| **EC2 · NetworkIn por instancia** | Ambas instancias reciben tráfico (no una sola al 100%) |
| **RDS · DatabaseConnections** | Sube proporcional a los POSTs |
| **RDS · CPU** | Sube pero se queda lejos de 80% |

Si al final del test:
- Las 2 líneas de **CPU EC2** están casi pegadas → ALB está balanceando correctamente
- `error rate < 5%` y `p95 < 1500ms` → la infra soporta la carga
- 0 alarmas dispararon → el sistema mantuvo SLO durante toda la prueba
