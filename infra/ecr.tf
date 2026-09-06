# ==========================================
# ECR Private Repositories
# ==========================================
resource "aws_ecr_repository" "backend" {
  name                 = "sbcntr-backend-app"
  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "sbcntr-backend-app"
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "sbcntr-frontend-app"
  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "sbcntr-frontend-app"
  }
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
