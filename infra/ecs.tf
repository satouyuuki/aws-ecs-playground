# ==========================================
# ECS Cluster
# ==========================================
resource "aws_ecs_cluster" "app" {
  name = "sbcntr-app"

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }

  tags = {
    Name = "sbcntr-app"
  }
}

# ECS Cluster Capacity Providers (Fargate)
resource "aws_ecs_cluster_capacity_providers" "app" {
  cluster_name       = aws_ecs_cluster.app.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 0
    weight            = 1
  }
}

# ==========================================
# ECS Task Execution Role
# ==========================================
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExectionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]

  tags = {
    Name = "ecsTaskExectionRole"
  }
}

# ==========================================
# IAM Policy for ECS Task Execution (Secrets Manager)
# ==========================================
resource "aws_iam_role_policy" "ecs_secrets_policy" {
  name = "SbcntrGettingSecretsPolicy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_rds_cluster.postgresql.master_user_secret[0].secret_arn
      }
    ]
  })
}


# ==========================================
# ECS Task Role (for ECS Exec)
# ==========================================
resource "aws_iam_role" "ecs_task_role" {
  name = "SbcntrEcsTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  tags = {
    Name = "SbcntrEcsTaskRole"
  }
}

# ==========================================
# ECS Task Definition (Frontend)
# ==========================================
resource "aws_ecs_task_definition" "frontend" {
  family                   = "sbcntr-frontend-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"  # 0.5 vCPU
  memory                   = "1024" # 1 GB
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name                   = "app"
      image                  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com/sbcntr-frontend-app:v1"
      essential              = true
      cpu                    = 512
      memory                 = 1024
      readonlyRootFilesystem = false
      # readonlyRootFilesystem = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "BACKEND_FQDN", value = "backend-app.sbcntr.local" },
        { name = "BACKEND_PORT", value = "8081" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/sbcntr/ecs/frontend-app"
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])

  tags = {
    Name = "sbcntr-frontend-app"
  }
}

# ==========================================
# CloudWatch Log Group for ECS Frontend
# ==========================================
resource "aws_cloudwatch_log_group" "frontend_app" {
  name              = "/sbcntr/ecs/frontend-app"
  retention_in_days = 30

  tags = {
    Name = "sbcntr-ecs-frontend-app-logs"
  }
}

# ==========================================
# ECS Service (Frontend with CodeDeploy B/G)
# ==========================================
resource "aws_ecs_service" "frontend" {
  name            = "sbcntr-frontend-app"
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_app_a.id, aws_subnet.private_app_c.id]
    security_groups  = [aws_security_group.frontend.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontapp_blue.arn
    container_name   = "app"
    container_port   = 8080
  }

  # ★ ECS Execを有効化
  enable_execute_command = true

  # Blue/Greenデプロイメント（CodeDeploy連携）を使用する場合、
  # 初回作成後のタスク定義やロードバランサーの変更はCodeDeploy経由で行うためライフサイクル設定を推奨
  lifecycle {
    ignore_changes = [
      # task_definition,
      load_balancer
    ]
  }

  deployment_controller {
    type = "ECS"
  }

  # サーキットブレーカーの設定
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  health_check_grace_period_seconds = 60

  depends_on = [
    aws_lb_listener.http
  ]

  tags = {
    Name = "sbnctr-frontend-app"
  }
}
