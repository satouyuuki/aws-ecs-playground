# ==========================================
# VPC Endpoint (Interface型: CloudWatch Logs)
# ==========================================
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_ingress_a.id, aws_subnet.private_ingress_c.id]
  security_group_ids  = [aws_security_group.egress.id]
  private_dns_enabled = true

  # policy = jsonencode({
  #   Version = "2012-10-17"
  #   Statement = [
  #     {
  #       Effect    = "Allow"
  #       Principal = "*"
  #       Action    = "*"
  #       Resource  = "*"
  #     }
  #   ]
  # })

  tags = {
    Name = "sbnctr-logs"
  }
}

# ==========================================
# ALB & Target Groups
# ==========================================
# Target Group: Blue
resource "aws_lb_target_group" "frontapp_blue" {
  name             = "sbcntr-frontapp-blue"
  port             = 8080
  protocol         = "HTTP"
  vpc_id           = aws_vpc.main.id
  target_type      = "ip"
  ip_address_type  = "ipv4"
  protocol_version = "HTTP1"

  health_check {
    path                = "/healthcheck"
    protocol            = "HTTP"
    port                = "8080"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "sbcntr-frontapp-blue"
  }
}

# Target Group: Green
resource "aws_lb_target_group" "frontapp_green" {
  name             = "sbcntr-frontapp-green"
  port             = 8080
  protocol         = "HTTP"
  vpc_id           = aws_vpc.main.id
  target_type      = "ip"
  ip_address_type  = "ipv4"
  protocol_version = "HTTP1"

  health_check {
    path                = "/healthcheck"
    protocol            = "HTTP"
    port                = "8080"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "sbcntr-frontapp-green"
  }
}

# ALB (Internet-facing)
resource "aws_lb" "ingress" {
  name                       = "sbcntr-ingress"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.ingress.id]
  subnets                    = [aws_subnet.public_ingress_a.id, aws_subnet.public_ingress_c.id]
  ip_address_type            = "ipv4"
  enable_deletion_protection = false

  tags = {
    Name = "sbnctr-ingress"
  }
}

# ALB Listener (HTTP:80 with Blue/Green weighted routing)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ingress.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.frontapp_blue.arn
        weight = 1
      }

      target_group {
        arn    = aws_lb_target_group.frontapp_green.arn
        weight = 0
      }
    }
  }
}

# ==========================================
# IAM Role for ECS Blue/Green Deployments
# ==========================================
resource "aws_iam_role" "ecs_infrastructure_role" {
  name = "EcsInfrastructureRoleForLoadBalancers"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
  ]

  tags = {
    Name = "EcsInfrastructureRoleForLoadBalancers"
  }
}
