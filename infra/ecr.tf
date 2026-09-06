# ==========================================
# ECR Private Repositories
# ==========================================
resource "aws_ecr_repository" "backend" {
  name                 = "${local.prefix}-backend-app"
  image_tag_mutability = "IMMUTABLE"

  # 非推奨
  # image_scanning_configuration {
  #   scan_on_push = true
  # }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${local.prefix}-backend-app"
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "${local.prefix}-frontend-app"
  image_tag_mutability = "IMMUTABLE"

  # 非推奨
  # image_scanning_configuration {
  #   scan_on_push = true
  # }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${local.prefix}-frontend-app"
  }
}

# ライフサイクルルールの追加（古い世代のイメージを削除：最新3つを残す）
resource "aws_ecr_lifecycle_policy" "frontend_lifecycle" {
  repository = aws_ecr_repository.frontend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "古いの世代のイメージを削除"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "backend_lifecycle" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "古い世代のイメージを削除"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ==========================================
# Amazon Inspector (Enable ECR Scanning)
# ==========================================
resource "aws_inspector2_enabler" "main" {
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["ECR"]
}

# ==========================================
# ECR Registry Scanning Configuration (with sbcntr-* filter)
# ==========================================
resource "aws_ecr_registry_scanning_configuration" "main" {
  scan_type = "ENHANCED"

  # プッシュ時にスキャンするルール（sbcntr-* に一致するもの）
  rule {
    scan_frequency = "SCAN_ON_PUSH"

    repository_filter {
      filter      = "${local.prefix}-*"
      filter_type = "WILDCARD"
    }
  }

  # ※もし「継続的スキャン」を完全にオフ（あるいは別の頻度にしたい）場合は、
  #   上のように SCAN_ON_PUSH のルールだけを定義することで、
  #   不要な継続的スキャン（Continuous Scan）の全体有効化を防ぎ、
  #   指定した sbcntr-* リポジトリのプッシュ時のみスキャンを行う挙動に絞ることができます。
  rule {
    scan_frequency = "CONTINUOUS_SCAN"

    repository_filter {
      filter      = "${local.prefix}-*"
      filter_type = "WILDCARD"
    }
  }

  depends_on = [aws_inspector2_enabler.main]
}

# ==========================================
# VPC Endpoints (Interface型: ECR API / ECR DKR)
# ==========================================
# ECR API用 VPCE
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.ecr.api"
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
    Name = "sbnctr-ecr-api"
  }
}

# ECR DKR用 VPCE
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.ecr.dkr"
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
    Name = "sbnctr-ecr-dkr"
  }
}

# ==========================================
# VPC Endpoint (Gateway型: S3 / ECRレイヤー取得用)
# ==========================================
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.app.id]

  tags = {
    Name = "sbnctr-s3-gateway"
  }
}
