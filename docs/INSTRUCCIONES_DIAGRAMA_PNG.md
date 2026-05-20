# Cómo generar `diagrama.png` con iconos oficiales AWS 2026

El `.md` de evaluación **exige iconos oficiales de AWS 2026**. El Mermaid de `diagrama.mmd` sirve como referencia técnica pero NO usa iconos AWS reales. Para el video necesitas el PNG con stencils oficiales.

## Opción A (recomendada): draw.io / diagrams.net

Es gratis, web, exporta PNG/PDF y trae el set oficial 2026.

### Pasos (≤10 minutos)

1. Abre https://app.diagrams.net/
2. "Create New Diagram" → Blank Diagram → Create
3. En el panel izquierdo: **More Shapes...** (al final del panel)
4. Marca: **AWS / AWS19** y **AWS / AWS21** (set actualizado, contiene iconos 2026)
5. Apply

### Elementos a colocar (siguiendo `diagrama.mmd`)

Replica la estructura del Mermaid usando estos iconos:

| Mermaid | Stencil oficial AWS a usar |
|---|---|
| 👤 Usuario | `Users` (genérico) |
| 👨‍💻 Developer | `User` |
| 🐙 GitHub Actions | Logo GitHub Actions (busca "github" o usa una caja con texto) |
| ☁️ AWS Cloud | `AWS Cloud` (contenedor) |
| 🌐 VPC | `VPC` |
| 🌍 Internet Gateway | `Internet Gateway` |
| 🟢 Subred pública | `Public subnet` |
| 🔒 Subred privada | `Private subnet` |
| ⚖️ ALB | `Application Load Balancer` |
| 🔁 NAT Gateway | `NAT Gateway` |
| 💻 EC2 | `EC2 Instance` |
| 🗄️ RDS | `RDS` (con badge "Multi-AZ") |
| 📦 ECR | `ECR` o `Elastic Container Registry` |
| 📊 CloudWatch | `CloudWatch` |
| 🛡️ Security Group | `Security group` |

### Layout sugerido

```
   [Users]   [Developer → GitHub Actions]
       │              │
       ▼              ▼
┌──── AWS Cloud (us-east-1) ──────────────────────┐
│  ┌── VPC 10.0.0.0/16 ────────────────────────┐  │
│  │  [IGW]                                    │  │
│  │  ┌── AZ us-east-1a ──┐  ┌── AZ us-east-1b ──┐│
│  │  │  Pub: [ALB][NAT]  │  │  Pub: [ALB]       ││
│  │  │  Priv:[EC2][RDS-p]│  │  Priv:[EC2][RDS-s]││
│  │  └───────────────────┘  └────────────────────┘│
│  └─────────────────────────────────────────────┘ │
│  [ECR]   [CloudWatch]                            │
└──────────────────────────────────────────────────┘
```

### Flechas a dibujar

- Línea sólida: tráfico de usuario (User → IGW → ALB → EC2 → RDS)
- Línea sólida: réplica RDS Multi-AZ entre AZs
- Línea punteada: CI/CD (Dev → GH Actions → ECR ← EC2 pull)
- Línea punteada gris: logs/metrics (EC2/ALB/RDS → CloudWatch)
- Etiqueta cada flecha con protocolo: `HTTP:80`, `HTTP:8000`, `TCP:5432`

### Exportar

1. File → Export As → PNG
2. Border: 20, Zoom: 200%, Background: White
3. Guarda como `diagrama.png` en `docs/`

## Opción B: Cloudcraft

https://www.cloudcraft.co/ — visualmente más vistoso (isométrico), versión gratis suficiente. Mismos iconos AWS 2026.

## Opción C: PowerPoint/Keynote con stencils oficiales

Descarga el toolkit oficial:
https://aws.amazon.com/architecture/icons/

Trae .pptx y .key con los iconos 2026 listos para arrastrar.

## Verificación antes de grabar

Antes de F7 (grabación), valida:
- [ ] El PNG muestra **usuarios**
- [ ] Muestra **VPC** y **2 subredes** (pública + privada × 2 AZ)
- [ ] Muestra **balanceador** (ALB)
- [ ] Muestra **instancias de cómputo** (2× EC2)
- [ ] Muestra **Security Groups** (las 3 capas)
- [ ] Muestra **base de datos** (RDS) y **almacenamiento** (ECR)
- [ ] Muestra **flujo CI/CD** (GitHub → ECR → EC2)
- [ ] Muestra **flujo de tráfico** (User → ALB → EC2 → RDS)
- [ ] Los iconos son del set oficial AWS 2026

Si falta alguno → la rúbrica de Arquitectura (10%) se ve afectada.
