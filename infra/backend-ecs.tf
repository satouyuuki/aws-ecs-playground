# ==========================================
# CloudWatch Log Group for ECS Backend
# ==========================================
resource "aws_cloudwatch_log_group" "backend_app" {
  name              = "/sbnctr/ecs/backend-app"
  retention_in_days = 14

  tags = {
    Project = "sbnctr"
    Name    = "sbnctr-backend-app-logs"
  }
}

# ==========================================
# Service Discovery (Cloud Map)
# ==========================================
resource "aws_service_discovery_private_dns_namespace" "sbcntr" {
  name        = "${local.prefix}.local"
  description = "${local.prefix} local namespace for ECS services"
  vpc         = aws_vpc.main.id

  tags = {
    Project = "sbnctr"
  }
}

resource "aws_service_discovery_service" "backend" {
  name        = "backend-app"
  description = "Backend App Service"

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.sbcntr.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# ==========================================
# ECS Task Definition (Backend)
# ==========================================
resource "aws_ecs_task_definition" "backend" {
  family                   = "sbnctr-backend-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name              = "app"
      image             = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com/${local.prefix}-backend-app:v1"
      essential         = true
      cpu               = 256
      memoryReservation = 256
      portMappings = [
        {
          containerPort = 8081
          hostPort      = 8081
          protocol      = "tcp"
        }
      ]
      secrets = [
        # {
        #   name      = "DB_HOST"
        #   valueFrom = "${aws_rds_cluster.postgresql.master_user_secret[0].secret_arn}:host::"
        # },
        {
          name      = "DB_USERNAME"
          valueFrom = "${aws_rds_cluster.postgresql.master_user_secret[0].secret_arn}:username::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_rds_cluster.postgresql.master_user_secret[0].secret_arn}:password::"
        }
      ]
      environment = [
        {
          name  = "DB_HOST"
          value = aws_rds_cluster.postgresql.endpoint
        },
        {
          name  = "DB_NAME"
          value = "app"
        },
        {
          name  = "DB_CONN"
          value = "1"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/sbnctr/ecs/backend-app"
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Project = "sbnctr"
    Name    = "sbnctr-backend-app"
  }
}

# ==========================================
# ECS Service (Backend)
# ==========================================
resource "aws_ecs_service" "backend" {
  name                              = "sbnctr-backend-app"
  cluster                           = aws_ecs_cluster.app.id
  task_definition                   = aws_ecs_task_definition.backend.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  platform_version                  = "1.4.0"
  enable_ecs_managed_tags           = true
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = [aws_subnet.private_app_a.id, aws_subnet.private_app_c.id]
    security_groups  = [aws_security_group.backend.id]
    assign_public_ip = false
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  # deployment_configuration {
  #   maximum_percent         = 200
  #   minimum_healthy_percent = 100
  # }

  service_registries {
    registry_arn = aws_service_discovery_service.backend.arn
    # container_port = 8081
  }

  tags = {
    Project = "sbnctr"
    Name    = "sbnctr-backend-app"
  }
}
