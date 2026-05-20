###############################################################################
# Outputs principales — los que se muestran en `terraform output`
###############################################################################
output "alb_dns_name" {
  description = "DNS público del Application Load Balancer (acceso a la app)"
  value       = aws_lb.this.dns_name
}

output "alb_url" {
  description = "URL HTTP completa del ALB"
  value       = "http://${aws_lb.this.dns_name}"
}

output "health_url" {
  description = "Endpoint de health check para validar el servicio"
  value       = "http://${aws_lb.this.dns_name}/health"
}

output "swagger_url" {
  description = "Documentación Swagger interactiva del servicio"
  value       = "http://${aws_lb.this.dns_name}/docs"
}

output "container_image" {
  description = "Imagen Docker publica que despliegan las EC2 (ghcr.io)"
  value       = var.container_image
}

output "vpc_id" {
  description = "ID de la VPC creada"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas (alojan ALB y NAT)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs de las subredes privadas (alojan EC2 y RDS)"
  value       = aws_subnet.private[*].id
}

output "asg_name" {
  description = "Nombre del Auto Scaling Group de la app"
  value       = aws_autoscaling_group.app.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group para logs de la aplicación"
  value       = aws_cloudwatch_log_group.app.name
}

output "rds_endpoint" {
  description = "Endpoint privado de RDS PostgreSQL (no accesible desde Internet)"
  value       = aws_db_instance.this.address
  sensitive   = true
}

output "rds_database_name" {
  description = "Nombre de la base de datos creada"
  value       = aws_db_instance.this.db_name
}

output "db_password" {
  description = "Password generado para el usuario master (sensible)"
  value       = random_password.db.result
  sensitive   = true
}

output "aws_region" {
  description = "Región AWS donde se desplegó la infraestructura"
  value       = var.aws_region
}

output "cloudwatch_dashboard_url" {
  description = "URL del dashboard CloudWatch consolidado (abrir en el video)"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
