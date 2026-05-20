# Arquitectura — Evaluación Final DGITI

**Proyecto:** `eval-final-dgiti`
**Patrón arquitectónico:** Three-Tier HA en AWS (Web → App → Data)
**Región:** `us-east-1`
**Modelo de despliegue:** AWS Academy (cuenta sandbox)

---

## 1. Vista general

Arquitectura de **alta disponibilidad** distribuida en **2 Zonas de Disponibilidad** (us-east-1a, us-east-1b), con separación clara entre capas pública (acceso) y privada (cómputo + datos). El tráfico de usuarios entra por un **Application Load Balancer (ALB)** que distribuye sobre **dos instancias EC2** ejecutando el servicio FastAPI containerizado, las cuales consultan una **base de datos RDS PostgreSQL Multi-AZ** ubicada en subredes privadas. El pipeline de CI/CD (GitHub Actions) construye la imagen Docker, la publica en **Amazon ECR** y dispara el refresh del Auto Scaling Group.

### Flujos principales

**Flujo de tráfico de usuarios:**
```
Usuario → Internet Gateway → ALB (subred pública)
       → Target Group → EC2 (subred privada AZ-a/AZ-b)
       → RDS Postgres Multi-AZ (subred privada)
```

**Flujo de despliegue CI/CD:**
```
Developer → git push (main) → GitHub Actions
         → lint + test + build
         → docker push → ECR
         → aws ec2 trigger refresh (ASG instance refresh)
         → user_data.sh → docker pull → app actualizada
```

---

## 2. Componentes detallados

### 2.1 Red — VPC

| Recurso | Valor | Propósito |
|---|---|---|
| VPC CIDR | `10.0.0.0/16` | Espacio de direcciones del proyecto |
| Subred pública AZ-a | `10.0.1.0/24` | ALB + NAT Gateway |
| Subred pública AZ-b | `10.0.2.0/24` | ALB (segunda AZ) |
| Subred privada AZ-a | `10.0.11.0/24` | EC2 app + RDS primary |
| Subred privada AZ-b | `10.0.12.0/24` | EC2 app + RDS standby |
| Internet Gateway | 1 | Salida/entrada a Internet para subredes públicas |
| NAT Gateway | 1 (en AZ-a) | Salida a Internet de instancias privadas (pull ECR, paquetes) |
| Route table pública | 1 | `0.0.0.0/0 → IGW` |
| Route table privada | 1 | `0.0.0.0/0 → NAT` |

**Decisión de costos:** un solo NAT Gateway (no uno por AZ) por restricciones de Academy. Trade-off: si la AZ del NAT cae, las instancias en AZ-b pierden salida a Internet hasta failover manual. Aceptable en entorno académico.

### 2.2 Cómputo — Auto Scaling Group + EC2

| Recurso | Valor | Justificación |
|---|---|---|
| AMI | Amazon Linux 2023 | Soporte Docker nativo, larga vida |
| Tipo de instancia | `t3.micro` | Free-tier; suficiente para FastAPI bajo carga moderada |
| ASG min/desired/max | 2 / 2 / 4 | Mínimo 2 garantiza HA; max 4 deja margen ante k6 |
| Distribución | 1 por AZ obligatoria | Verdadera HA si una AZ falla |
| User data | Script Bash que ejecuta `docker pull` desde ECR y arranca contenedor en puerto 8000 | Permite re-deploy via ASG instance refresh |
| Health check | ALB health check (no EC2 status) | El ALB es la fuente de verdad de salud aplicativa |
| IAM Instance Profile | `LabInstanceProfile` con `LabRole` | Restricción Academy: no se pueden crear roles nuevos |

### 2.3 Balanceo — Application Load Balancer

| Atributo | Valor |
|---|---|
| Esquema | `internet-facing` |
| Subnets | Las 2 subredes públicas (multi-AZ) |
| Listener | HTTP :80 → forward → Target Group |
| Algoritmo | Round-robin (default) |
| Health check | `GET /health` cada 30s, threshold 2 |
| Stickiness | Desactivado (sin estado en la app) |
| Target type | `instance` |

**Por qué ALB y no NLB/CLB:**
- Layer 7 → routing por path en el futuro
- Métricas más ricas en CloudWatch (TargetResponseTime, HTTPCode_Target_*)
- Health checks HTTP nativos
- Soporte WebSockets si se necesitara

### 2.4 Base de Datos — RDS PostgreSQL

| Atributo | Valor | Justificación |
|---|---|---|
| Engine | PostgreSQL 15 | Estándar; soporta SQLAlchemy 2.0 + asyncpg |
| Clase | `db.t3.micro` | Free-tier; suficiente para evaluación |
| Multi-AZ | **YES** | **Cumple requisito "BD con réplica"** del .md |
| Storage | 20 GB gp3 cifrado | Cifrado en reposo (best practice) |
| Public access | **NO** | **Cumple "acceso restringido únicamente desde infraestructura privada"** |
| Subnet group | Las 2 subredes privadas | Aislamiento de red |
| Backup retention | 1 día (mínimo en Academy) | Suficiente para demo |
| Parameter group | default | Sin tuning custom |
| Credenciales | Usuario master en variables Terraform (sensitive), password generado con `random_password` | Nunca en Git |

> **Aclaración técnica importante para la sustentación:** "Multi-AZ" en RDS PostgreSQL crea una **réplica standby síncrona en otra AZ**. No es leíble, pero garantiza failover automático y persistencia de datos ante caída de AZ. Cumple semánticamente el requisito de "réplica" del .md. Si el evaluador pide réplica de lectura, se puede agregar un Read Replica con un solo recurso Terraform adicional.

### 2.5 Registro de imágenes — Amazon ECR

| Atributo | Valor |
|---|---|
| Tipo | Private repository |
| Lifecycle policy | Mantener últimas 10 imágenes |
| Scan on push | Habilitado |
| Tags | `latest` + `commit-sha` |

### 2.6 Observabilidad — CloudWatch

| Recurso | Para qué |
|---|---|
| Log group `/eval-final-dgiti/app` | stdout/stderr del contenedor (vía awslogs driver) |
| Metric: ALB `RequestCount` | Volumen de tráfico — clave en F6 |
| Metric: ALB `TargetResponseTime` | Latencia p95 — clave en F6 |
| Metric: ALB `HTTPCode_Target_5XX_Count` | Errores app — clave en F6 |
| Metric: ALB `HealthyHostCount` | Targets sanos — evidencia HA |
| Metric: EC2 `CPUUtilization` | Saturación cómputo durante k6 |
| Dashboard `eval-final-dgiti` | Panel consolidado visible en el video |
| Alarm `app-5xx-high` | ≥5 errores 5XX en 5 min (opcional pero suma) |

---

## 3. Seguridad — Security Groups (least privilege)

### 3.1 `alb-sg` (Application Load Balancer)

| Regla | Tipo | Protocolo | Puerto | Origen | Razón |
|---|---|---|---|---|---|
| Ingress 1 | TCP | HTTP | 80 | `0.0.0.0/0` | Acceso público al servicio |
| Egress 1 | TCP | TCP | 8000 | `app-sg` | Forward al target group |

### 3.2 `app-sg` (EC2 con FastAPI)

| Regla | Tipo | Protocolo | Puerto | Origen | Razón |
|---|---|---|---|---|---|
| Ingress 1 | TCP | TCP | 8000 | `alb-sg` | **Solo el ALB puede tocar la app** |
| Egress 1 | TCP | TCP | 5432 | `db-sg` | Conexión a Postgres |
| Egress 2 | TCP | HTTPS | 443 | `0.0.0.0/0` | Pull desde ECR, updates yum |

### 3.3 `db-sg` (RDS PostgreSQL)

| Regla | Tipo | Protocolo | Puerto | Origen | Razón |
|---|---|---|---|---|---|
| Ingress 1 | TCP | TCP | 5432 | `app-sg` | **Solo la app puede tocar la BD** |
| Egress | — | — | — | — | Sin egress |

**Principio:** cada capa solo acepta tráfico de la capa inmediatamente superior. La BD nunca es alcanzable desde Internet ni desde el ALB directamente. Cumple el requisito del .md: *"controles de acceso de red mediante reglas de seguridad adecuadamente configuradas"*.

---

## 4. Decisiones técnicas y trade-offs

### 4.1 ¿Por qué EC2 + ASG y no ECS Fargate?

| Criterio | EC2 + ASG | ECS Fargate |
|---|---|---|
| Visibilidad en consola | **Alta** (instancias EC2 individuales) | Media (tareas abstraídas) |
| Demostración HA en video | **Fácil** (terminar instancia → ALB redirige visible) | Más opaco |
| Compatibilidad Academy | Total | Total pero más permisos IAM |
| Complejidad Terraform | Baja | Media |
| **Decisión** | ✅ **Elegido** | Descartado |

### 4.2 ¿Por qué 1 NAT Gateway y no 1 por AZ?

NAT Gateway cuesta ~$32/mes por AZ. AWS Academy tiene presupuesto limitado y la sesión es ephemeral; un solo NAT en AZ-a basta. **Riesgo aceptado**: si AZ-a cae, instancias en AZ-b pierden salida a Internet (no la entrada — el ALB sigue ruteando entrada cross-AZ). Para producción real se usaría 1 NAT por AZ.

### 4.3 ¿Por qué Multi-AZ y no Read Replica?

El .md pide "base de datos con réplica". Hay dos opciones:
- **Multi-AZ (standby síncrona):** failover automático, no lecturas separadas, garantiza durabilidad.
- **Read Replica (asíncrona):** sirve lecturas adicionales, no failover automático.

**Elegido Multi-AZ** porque:
1. Cumple semánticamente "réplica con acceso restringido".
2. La app no tiene tráfico de lectura suficiente para justificar split read/write.
3. Aporta HA real (failover < 60s).

### 4.4 ¿Por qué `t3.micro` en EC2 y RDS?

Free-tier de AWS Academy. Soporta los 50 VUs de k6 sin saturarse antes de la prueba (lo cual sería contraproducente para la demo). Si se quisiera dramatizar saturación en F6, se podría bajar a `t2.micro` para forzar CPU al 100% antes.

### 4.5 ¿Por qué no Aurora?

Aurora es superior a RDS Postgres estándar, pero:
1. Más costoso (no free-tier).
2. Más complejo de configurar en Terraform.
3. La demo no requiere su rendimiento.

RDS Postgres Multi-AZ es la elección pragmática.

---

## 5. Restricciones AWS Academy aplicadas

| Restricción | Cómo se maneja |
|---|---|
| No crear IAM users | Usar `LabRole` y `LabInstanceProfile` existentes |
| Credenciales temporales (~4h) | Re-exportar `AWS_SESSION_TOKEN` antes de cada `terraform apply` y antes de correr el pipeline |
| Sin servicios premium (Organizations, Control Tower) | Arquitectura no los usa |
| Tag obligatorio en algunos recursos | Aplicar `tags = { Project = "eval-final-dgiti" }` en todos los recursos |
| Limit en algunos tipos de instancia | Usar solo `t3.micro` / `t3.small` para evitar bloqueos |

---

## 6. Mapeo a la rúbrica de evaluación

| Criterio | Peso | Cómo lo cubre esta arquitectura |
|---|---|---|
| Arquitectura | 10% | Este documento + diagrama AWS 2026 + justificación verbal en el video |
| IaC Terraform | 25% | Toda esta arquitectura está codificada en `infra/` |
| Servicio desplegado | 10% | FastAPI corre en las 2 EC2, alcanzable vía ALB DNS |
| Pipeline CI/CD | 25% | GitHub Actions → ECR → ASG refresh (sin tocar Terraform en runtime) |
| Desempeño y monitoreo | 30% | ALB + CloudWatch + k6 demuestran balanceo y métricas |

---

## 7. Diagrama

Ver `docs/diagrama.mmd` (Mermaid) y `docs/diagrama.png` (export con iconos oficiales AWS 2026).

Para el video, **se usa la versión PNG con iconos oficiales** (requerimiento del .md).
