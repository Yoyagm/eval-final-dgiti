# Checklist — Qué navegar en la consola AWS durante el video

Este documento lista **exactamente** qué clicar en la consola de AWS Academy durante la grabación. Todo lo que aparece aquí se crea solo con `terraform apply` — tú no creas nada manual, solo lo muestras.

> Mantén estas pestañas pre-abiertas antes de grabar para no perder tiempo buscando.

---

## 🔗 URLs directas (sustituye `us-east-1` si usas otra región)

| # | Servicio | Path en consola | Para qué |
|---|---|---|---|
| 1 | **VPC** | `https://us-east-1.console.aws.amazon.com/vpcconsole/home?region=us-east-1#vpcs` | Mostrar VPC + 4 subredes |
| 2 | **EC2 → Load Balancers** | `https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#LoadBalancers:` | ALB activo, listener :80 |
| 3 | **EC2 → Target Groups** | `https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#TargetGroups:` | 2 targets healthy |
| 4 | **EC2 → Auto Scaling Groups** | `https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#AutoScalingGroups:` | ASG con 2 instances |
| 5 | **EC2 → Instances** | `https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#Instances:` | 2 EC2 running en distintas AZ |
| 6 | **EC2 → Security Groups** | `https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#SecurityGroups:` | 3 SGs least-privilege |
| 7 | **RDS → Databases** | `https://us-east-1.console.aws.amazon.com/rds/home?region=us-east-1#databases:` | Instancia Multi-AZ available |
| 8 | **ECR → Repositories** | `https://us-east-1.console.aws.amazon.com/ecr/repositories?region=us-east-1` | Imagen pusheada con tag SHA |
| 9 | **CloudWatch → Dashboard** | obtenida con `terraform output -raw cloudwatch_dashboard_url` | Dashboard consolidado |
| 10 | **CloudWatch → Log groups** | `https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups` | Logs de la app |
| 11 | **CloudWatch → Alarms** | `https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#alarmsV2:` | 4 alarmas |
| 12 | **GitHub → Actions** | `https://github.com/Yoyagm/eval-final-dgiti/actions` | Pipeline verde |
| 13 | **GitHub → Secrets** | `https://github.com/Yoyagm/eval-final-dgiti/settings/secrets/actions` | 4 secrets configurados |

---

## 🎬 Orden recomendado durante el video

### Bloque ARQUITECTURA (0:00–0:30) — solo el diagrama
- Mostrar `docs/diagrama.png` en pantalla completa
- No tocas consola AWS todavía

### Bloque IaC TERRAFORM (0:30–3:00)
1. Terminal: `terraform init` (saltar lo ya cacheado mostrando el output)
2. Terminal: `terraform plan` → leer resumen "0 to add" (porque ya está aplicado)
3. Terminal: `terraform output` → resaltar `alb_dns_name`, `cloudwatch_dashboard_url`
4. **Tab 1 (VPC)** → mostrar VPC, click en "Subnets" del menú lateral → 4 subredes con tags públicas/privadas
5. **Tab 2 (Load Balancers)** → click ALB → pestaña "Listeners and rules" → :80 forward al TG
6. **Tab 3 (Target Groups)** → click TG → pestaña "Targets" → **2 instancias healthy**
7. **Tab 7 (RDS)** → click la BD → pestaña "Configuration" → resaltar **Multi-AZ: Yes**
8. **Tab 6 (Security Groups)** → mostrar las 3 reglas (alb-sg, app-sg, db-sg)

### Bloque SERVICIO (3:00–4:00)
1. Terminal: `./scripts/test_endpoints.sh` → 8 checks PASS
2. Navegador: abrir `http://<alb-dns>/docs` → ejecutar un POST desde Swagger
3. **Tab 5 (EC2 Instances)** → 2 instancias running, una en `us-east-1a` y otra en `us-east-1b`
4. **Tab 10 (CloudWatch Logs)** → click log group `/eval-final-dgiti/app` → mostrar líneas recientes

### Bloque CI/CD (4:00–6:30)
1. **Tab 13 (GitHub Secrets)** → 4 nombres visibles (valores enmascarados)
2. Terminal: `git commit --allow-empty -m "demo video"` + `git push`
3. **Tab 12 (GitHub Actions)** → click el run en curso:
   - Job `lint` ✓
   - Job `test` ✓ con coverage
   - Job `docker-build` ✓
   - (En `cd.yml`): build-and-push ✓
   - refresh-asg ✓
4. **Tab 8 (ECR)** → click repo → ver imagen con tag `SHA-corto` recién subida
5. **Tab 4 (ASG)** → pestaña "Instance refresh" → refresh en progreso

### Bloque DESEMPEÑO + MONITOREO (6:30–9:30) — el más pesado
1. Terminal: `BASE_URL=$(cd infra && terraform output -raw alb_url) k6 run load/load_test.js`
2. **Tab 9 (Dashboard CloudWatch)** abierta en split-screen:
   - Fila 1: ver RequestCount subir + latencia + 5XX en 0 + 2 healthy hosts
   - Fila 2: **resaltar CPU per instance → 2 líneas paralelas** (esto es la prueba del balanceo)
   - Fila 3: RDS connections subiendo, CPU controlado
   - Fila 4: logs en vivo
3. **Tab 3 (Target Group → Targets)** en otro tab: ambos targets siguen healthy
4. (Opcional) **Tab 5 (EC2 Instances)** → terminar 1 instancia manualmente → mostrar HA
5. Terminal: cuando k6 termina, leer el summary
6. **Tab 11 (CloudWatch Alarms)** → mostrar las 4 alarmas en estado OK durante la prueba

### Bloque CIERRE (9:30–10:00)
1. Mostrar el repo en GitHub
2. Terminal: `terraform destroy -auto-approve` (opcional, si hay tiempo grábalo aunque sea iniciándolo)
3. Cerrar el Lab de AWS Academy

---

## ❓ Preguntas frecuentes

**P: ¿Tengo que crear widgets manualmente en CloudWatch?**
R: No. El dashboard `eval-final-dgiti-overview` se crea automáticamente con `terraform apply`. Tú solo lo abres con la URL del output.

**P: ¿Y si quiero agregar más métricas durante el video?**
R: Puedes ir a CloudWatch → Metrics → All metrics y explorar manualmente, pero no es necesario para la rúbrica. El dashboard ya cubre los 4 golden signals.

**P: ¿La consola AWS Academy se ve igual que la consola normal?**
R: Sí, idéntica. Solo cambia que tu sesión expira al cerrar el Lab.

**P: ¿Qué pasa si una pestaña dice "No tienes permisos"?**
R: Academy bloquea Organizations, IAM Users, algunos servicios premium. Pero todo lo que listé arriba (VPC, EC2, RDS, ECR, CloudWatch) funciona en Academy.

**P: ¿Y si los widgets del dashboard salen vacíos al abrirlo recién creado?**
R: CloudWatch tarda ~2 min en empezar a agregar métricas. Si grabas inmediatamente post-apply, ajusta el time range del dashboard a "Last 15 min" o espera 2-3 min.
