# Guion del Video Demostrativo — Evaluación Final DGITI

**Duración objetivo:** ≤10:00 min
**Modalidad:** Demostración en vivo, integrante único, cuenta personal AWS Academy
**Tiempo distribuido según peso de rúbrica.**

---

## Preparación previa a grabar (no se graba)

- [ ] Lab AWS Academy iniciado (estado verde) y credenciales pegadas en `~/.aws/credentials` perfil `academy`
- [ ] `terraform apply` ya ejecutado y exitoso (infra desplegada y "caliente")
- [ ] Imagen Docker ya en ECR
- [ ] App respondiendo en el ALB DNS (probada con curl previo)
- [ ] Pipeline ya corrió al menos 1 vez exitosamente en GitHub
- [ ] k6 instalado (`brew install k6`)
- [ ] Tabs preparadas en navegador:
  1. GitHub repo `Yoyagm/eval-final-dgiti`
  2. GitHub Actions (último run verde)
  3. Diagrama de arquitectura (`docs/diagrama.png`)
  4. AWS Console — VPC dashboard
  5. AWS Console — EC2 Load Balancers
  6. AWS Console — RDS
  7. AWS Console — CloudWatch Dashboard
  8. AWS Console — EC2 Target Groups
  9. Swagger del servicio (`http://<alb-dns>/docs`)
- [ ] Terminal dividido en 2 paneles: izq para comandos, der para k6/tail logs
- [ ] Cámara web encendida (rostro en esquina)
- [ ] Audio probado
- [ ] Cronómetro visible

---

## Estructura cronometrada (10:00 total)

### 🎬 0:00 – 0:30 — Intro + Arquitectura (10%)
- Saludo: "Soy Johan David Rodríguez, evaluación final de DGITI, integrante único"
- Mostrar diagrama (`diagrama.png` con iconos AWS 2026)
- Decir en una frase: "VPC con 2 AZ, ALB en subred pública, 2 EC2 con FastAPI en privadas, RDS Postgres Multi-AZ"
- Justificar: "HA por las 2 AZ, BD aislada en privada por seguridad, SGs con least-privilege"

### 🎬 0:30 – 3:00 — Terraform IaC (25%)
- Mostrar estructura de `infra/` (provider/variables/main/outputs/tfvars.example/user_data)
- Terminal: `terraform init` (ya ejecutado, mostrar output cacheado o re-run rápido)
- `terraform validate` → ✓
- `terraform plan` → mostrar últimas líneas con "0 to add, 0 to change"
- `terraform output` → leer ALB DNS y endpoints
- Saltar a consola AWS:
  - VPC: mostrar VPC creada y sus 4 subredes
  - EC2 → Load Balancers: ALB "active"
  - EC2 → Target Groups: ambos targets "healthy"
  - RDS: instancia "available", **Multi-AZ = Yes**
  - EC2 → Security Groups: mostrar las 3 reglas (alb-sg, app-sg, db-sg)

### 🎬 3:00 – 4:00 — Servicio desplegado (10%)
- Terminal: `curl http://<alb-dns>/health` → 200 JSON
- Navegador: abrir `http://<alb-dns>/docs` → Swagger UI
- Ejecutar desde Swagger: `POST /api/items` y `GET /api/items`
- Mostrar EC2 Instances en consola → 2 instancias `running`
- Mostrar CloudWatch Logs del log group de la app (últimas líneas con la request)

### 🎬 4:00 – 6:30 — Pipeline CI/CD (25%)
- GitHub → repo → Settings → Secrets and variables → Actions
  - Mostrar nombres: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `ECR_REPOSITORY`
  - "Los valores nunca se exponen, GitHub los enmascara"
- Hacer commit pequeño en `main` (ej. cambiar versión en README) y push
- GitHub Actions → run en vivo:
  - Job `lint` ✓
  - Job `test` ✓ (mostrar coverage)
  - Job `build` ✓ (mostrar push a ECR)
- Consola AWS → ECR → mostrar nueva imagen con tag del commit
- (Opcional rápido) AWS Systems Manager → mostrar el deployment trigger en EC2

### 🎬 6:30 – 9:30 — Desempeño y monitoreo (30%) — MÁS PESO
- Terminal izq: `k6 run load/load_test.js`
- Pantalla dividida: terminal con métricas en vivo + CloudWatch Dashboard
- Mientras k6 escala (0→50 VUs):
  - CloudWatch: `RequestCount` ALB sube
  - `TargetResponseTime` se mantiene
  - `CPUUtilization` EC2 sube en ambas instancias
- En la mitad: EC2 → Target Group → Targets → métricas: mostrar que **ambos targets reciben tráfico balanceado** (~50/50)
- (Si se anima) Terminar 1 instancia manualmente → ALB redirige todo a la otra → demuestra HA real
- Al finalizar k6: leer resumen
  - `http_req_duration p95 = X ms`
  - `http_req_failed = Y%`
  - `iterations = Z`
- Frase de cierre técnico: "El ALB distribuyó N requests entre 2 instancias, p95=Xms, error rate=Y%, evidenciando HA y balanceo"

### 🎬 9:30 – 10:00 — Cierre
- Mostrar URL del repo: `github.com/Yoyagm/eval-final-dgiti`
- (Opcional, si sobra tiempo) `terraform destroy -auto-approve` para mostrar limpieza
- "Gracias profesor Omar Pinzón"
- Cortar

---

## Lista de capturas/clips a tener listos (por si algo falla en vivo)

- `clip_terraform_apply.mov` — apply completo grabado antes
- `clip_pipeline_green.png` — pipeline verde (por si Actions falla en vivo)
- `clip_k6_summary.png` — summary final
- `clip_cloudwatch.png` — dashboard pintado

## Reglas de oro durante la grabación

1. **No leer un script.** Habla técnico, no narres botones.
2. **Cada acción genera evidencia visual.** Si dices algo, debe verse.
3. **Tu cara debe aparecer.** Webcam en esquina inferior.
4. **Mantén tabs preparadas.** No buscar en vivo.
5. **Si algo falla:** respira, explica qué pasó y reintenta. Mejor honesto que editado.
6. **Habla siempre de "decisiones técnicas".** No solo "hice X", sino "elegí X porque Y".
