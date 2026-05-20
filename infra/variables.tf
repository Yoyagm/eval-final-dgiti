###############################################################################
# Identidad del proyecto
###############################################################################
variable "project_name" {
  description = "Identificador corto del proyecto, usado como prefijo de recursos"
  type        = string
  default     = "eval-final-dgiti"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.project_name))
    error_message = "project_name debe ser lowercase, kebab-case, 3-31 chars."
  }
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment debe ser dev, staging o prod."
  }
}

###############################################################################
# Región y red
###############################################################################
variable "aws_region" {
  description = "Región AWS donde se despliegan todos los recursos"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs de subredes públicas (una por AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs de subredes privadas (una por AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "AZs a usar (deben coincidir con la región)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

###############################################################################
# Cómputo (EC2 + ASG)
###############################################################################
variable "instance_type" {
  description = "Tipo de instancia EC2 para los nodos de la app"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Mínimo de instancias en el ASG"
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Capacidad deseada del ASG"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Máximo de instancias en el ASG (margen para k6)"
  type        = number
  default     = 4
}

variable "app_port" {
  description = "Puerto donde escucha el contenedor FastAPI"
  type        = number
  default     = 8000
}

###############################################################################
# AWS Academy — rol existente (NO se crean roles nuevos)
###############################################################################
variable "instance_profile_name" {
  description = "Instance profile preexistente en AWS Academy"
  type        = string
  default     = "LabInstanceProfile"
}

###############################################################################
# Base de datos
###############################################################################
variable "db_instance_class" {
  description = "Tipo de instancia RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Storage RDS en GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
  default     = "items"
}

variable "db_username" {
  description = "Usuario master de RDS"
  type        = string
  default     = "appuser"
  sensitive   = true
}

variable "db_engine_version" {
  description = "Versión del engine PostgreSQL"
  type        = string
  default     = "15.7"
}

###############################################################################
# ECR
###############################################################################
variable "ecr_image_tag" {
  description = "Tag de la imagen Docker a desplegar"
  type        = string
  default     = "latest"
}
