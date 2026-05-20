###############################################################################
# Locals y data sources
###############################################################################
locals {
  name_prefix = var.project_name

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

data "aws_caller_identity" "current" {}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

###############################################################################
# RED — VPC, subredes, IGW, NAT, route tables
###############################################################################
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${local.name_prefix}-private-${var.availability_zones[count.index]}"
    Tier = "private"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${local.name_prefix}-nat"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.name_prefix}-rt-public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "${local.name_prefix}-rt-private"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

###############################################################################
# SECURITY GROUPS — least-privilege por capa
###############################################################################
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Permite HTTP entrante desde Internet hacia el ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP desde Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Hacia app en puerto de la app"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "App EC2 - accepts only from ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Traffic from ALB only"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Egress HTTPS to registry and packages"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Egress HTTP for yum updates"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Egress to Postgres in VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${local.name_prefix}-app-sg"
  }
}

resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db-sg"
  description = "RDS - accepts only from app SG"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Postgres from app only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  tags = {
    Name = "${local.name_prefix}-db-sg"
  }
}

###############################################################################
# CLOUDWATCH — log group para la app
###############################################################################
resource "aws_cloudwatch_log_group" "app" {
  name              = "/${local.name_prefix}/app"
  retention_in_days = 7

  tags = {
    Name = "${local.name_prefix}-log-group"
  }
}

###############################################################################
# AURORA PostgreSQL Serverless v2 — writer + reader replica en subredes privadas
# (AWS Academy bloquea rds:CreateDBInstance pero permite rds:CreateDBCluster)
###############################################################################
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*+-=?"
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

resource "aws_rds_cluster" "this" {
  cluster_identifier      = "${local.name_prefix}-aurora"
  engine                  = "aurora-postgresql"
  engine_version          = var.db_engine_version
  engine_mode             = "provisioned"
  database_name           = var.db_name
  master_username         = var.db_username
  master_password         = random_password.db.result
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  storage_encrypted       = true
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 1
  apply_immediately       = true

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 2.0
  }

  tags = {
    Name = "${local.name_prefix}-aurora-cluster"
  }
}

# Dos instancias: writer (primary) + reader (replica de lectura)
resource "aws_rds_cluster_instance" "this" {
  count                = 2
  identifier           = "${local.name_prefix}-aurora-${count.index}"
  cluster_identifier   = aws_rds_cluster.this.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.this.engine
  engine_version       = aws_rds_cluster.this.engine_version
  db_subnet_group_name = aws_db_subnet_group.this.name
  publicly_accessible  = false
  apply_immediately    = true

  tags = {
    Name = "${local.name_prefix}-aurora-instance-${count.index}"
    Role = count.index == 0 ? "writer" : "reader"
  }
}

###############################################################################
# ALB — listener HTTP, target group con health check /health
###############################################################################
resource "aws_lb" "this" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false
  idle_timeout               = 60

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name        = "${local.name_prefix}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 10
  }

  deregistration_delay = 30

  tags = {
    Name = "${local.name_prefix}-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

###############################################################################
# LAUNCH TEMPLATE + AUTO SCALING GROUP
###############################################################################
locals {
  database_url = "postgresql+asyncpg://${var.db_username}:${random_password.db.result}@${aws_rds_cluster.this.endpoint}:5432/${var.db_name}"

  user_data_rendered = base64encode(templatefile("${path.module}/user_data.sh", {
    aws_region      = var.aws_region
    container_image = var.container_image
    database_url    = local.database_url
    app_port        = var.app_port
    log_group       = aws_cloudwatch_log_group.app.name
  }))
}

resource "aws_launch_template" "app" {
  name_prefix   = "${local.name_prefix}-lt-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  user_data     = local.user_data_rendered

  iam_instance_profile {
    name = var.instance_profile_name
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 10
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name_prefix}-app"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "${local.name_prefix}-asg"
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  vpc_zone_identifier       = aws_subnet.private[*].id
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-app"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  depends_on = [aws_lb_listener.http]
}

###############################################################################
# CLOUDWATCH — Alarmas (golden signals: errors, saturation, healthy targets)
###############################################################################
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name_prefix}-alb-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_description   = "Más de 5 respuestas 5XX en 1 minuto desde los targets"

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${local.name_prefix}-unhealthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_description   = "Menos de 1 target sano en 2 minutos — la app no responde"

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  alarm_name          = "${local.name_prefix}-ec2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 75
  treat_missing_data  = "notBreaching"
  alarm_description   = "CPU promedio del ASG > 75% por 2 minutos — saturación"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${local.name_prefix}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_description   = "CPU RDS > 80% por 2 minutos — investigar queries"

  dimensions = {
    DBInstanceIdentifier = aws_rds_cluster_instance.this[0].identifier
  }
}

###############################################################################
# CLOUDWATCH — Dashboard consolidado para el video (peso 30% rúbrica)
###############################################################################
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-overview"

  dashboard_body = jsonencode({
    widgets = [
      # ===== Fila 1 — ALB (golden signals: traffic, errors, latency, availability) =====
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 6
        height = 6
        properties = {
          title  = "ALB · RequestCount (traffic)"
          region = var.aws_region
          stat   = "Sum"
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.this.arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 0
        width  = 6
        height = 6
        properties = {
          title  = "ALB · TargetResponseTime (latency)"
          region = var.aws_region
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.this.arn_suffix, { stat = "Average", label = "avg" }],
            ["...", { stat = "p95", label = "p95" }],
            ["...", { stat = "p99", label = "p99" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 6
        height = 6
        properties = {
          title  = "ALB · 4XX vs 5XX (errors)"
          region = var.aws_region
          stat   = "Sum"
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", aws_lb.this.arn_suffix],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 0
        width  = 6
        height = 6
        properties = {
          title  = "ALB · Healthy / Unhealthy hosts"
          region = var.aws_region
          stat   = "Average"
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.this.arn_suffix, "TargetGroup", aws_lb_target_group.app.arn_suffix],
            [".", "UnHealthyHostCount", ".", ".", ".", "."]
          ]
        }
      },
      # ===== Fila 2 — EC2 por instancia (mostrar balanceo del ALB) =====
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "EC2 · CPUUtilization por instancia (balanceo visible)"
          region = var.aws_region
          period = 60
          view   = "timeSeries"
          metrics = [
            [{ expression = "SEARCH('{AWS/EC2,InstanceId,AutoScalingGroupName} MetricName=\"CPUUtilization\" AutoScalingGroupName=\"${aws_autoscaling_group.app.name}\"', 'Average', 60)", label = "$${PROP('InstanceId')}", id = "e1" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "EC2 · NetworkIn por instancia (tráfico entrante)"
          region = var.aws_region
          period = 60
          view   = "timeSeries"
          metrics = [
            [{ expression = "SEARCH('{AWS/EC2,InstanceId,AutoScalingGroupName} MetricName=\"NetworkIn\" AutoScalingGroupName=\"${aws_autoscaling_group.app.name}\"', 'Sum', 60)", label = "$${PROP('InstanceId')}", id = "e2" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "EC2 · NetworkOut por instancia (respuestas)"
          region = var.aws_region
          period = 60
          view   = "timeSeries"
          metrics = [
            [{ expression = "SEARCH('{AWS/EC2,InstanceId,AutoScalingGroupName} MetricName=\"NetworkOut\" AutoScalingGroupName=\"${aws_autoscaling_group.app.name}\"', 'Sum', 60)", label = "$${PROP('InstanceId')}", id = "e3" }]
          ]
        }
      },
      # ===== Fila 3 — RDS (saturación BD) =====
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 6
        height = 6
        properties = {
          title  = "RDS · CPUUtilization"
          region = var.aws_region
          stat   = "Average"
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_rds_cluster_instance.this[0].identifier]
          ]
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 12
        width  = 6
        height = 6
        properties = {
          title  = "RDS · DatabaseConnections"
          region = var.aws_region
          stat   = "Average"
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_rds_cluster_instance.this[0].identifier]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 6
        height = 6
        properties = {
          title  = "RDS · FreeableMemory"
          region = var.aws_region
          stat   = "Average"
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", aws_rds_cluster_instance.this[0].identifier]
          ]
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 12
        width  = 6
        height = 6
        properties = {
          title  = "RDS · Read & Write Latency"
          region = var.aws_region
          stat   = "Average"
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", aws_rds_cluster_instance.this[0].identifier],
            [".", "WriteLatency", ".", "."]
          ]
        }
      },
      # ===== Fila 4 — Logs de la aplicación =====
      {
        type   = "log"
        x      = 0
        y      = 18
        width  = 24
        height = 6
        properties = {
          title  = "App · últimas 50 líneas de log (CloudWatch Logs)"
          region = var.aws_region
          query  = "SOURCE '${aws_cloudwatch_log_group.app.name}' | fields @timestamp, @message | sort @timestamp desc | limit 50"
          view   = "table"
        }
      }
    ]
  })
}
