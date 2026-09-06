terraform {
  required_version = ">= 1.15.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

# ==========================================
# VPC
# ==========================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "sbnctr-main"
  }
}

# ==========================================
# Internet Gateway
# ==========================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "sbnctr-main-igw"
  }
}

# ==========================================
# Subnets
# ==========================================
# 1. Ingress用
resource "aws_subnet" "public_ingress_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-northeast-1a"
  tags              = { Name = "sbnctr-public-ingress-a" }
}

resource "aws_subnet" "public_ingress_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-1c"
  tags              = { Name = "sbnctr-public-ingress-c" }
}

# 2. アプリケーション用
resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.8.0/24"
  availability_zone = "ap-northeast-1a"
  tags              = { Name = "sbnctr-private-app-a" }
}

resource "aws_subnet" "private_app_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.9.0/24"
  availability_zone = "ap-northeast-1c"
  tags              = { Name = "sbnctr-private-app-c" }
}

# 3. DB用
resource "aws_subnet" "private_db_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.16.0/24"
  availability_zone = "ap-northeast-1a"
  tags              = { Name = "sbnctr-private-db-a" }
}

resource "aws_subnet" "private_db_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.17.0/24"
  availability_zone = "ap-northeast-1c"
  tags              = { Name = "sbnctr-private-db-c" }
}

# 4. 管理用
resource "aws_subnet" "public_management_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.240.0/24"
  availability_zone = "ap-northeast-1a"
  tags              = { Name = "sbnctr-public-management-a" }
}

resource "aws_subnet" "public_management_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.241.0/24"
  availability_zone = "ap-northeast-1c"
  tags              = { Name = "sbnctr-public-management-c" }
}

# 5. Egress用 (※指定名に準拠)
resource "aws_subnet" "private_ingress_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.248.0/24"
  availability_zone = "ap-northeast-1a"
  tags              = { Name = "sbnctr-private-ingress-a" }
}

resource "aws_subnet" "private_ingress_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.249.0/24"
  availability_zone = "ap-northeast-1c"
  tags              = { Name = "sbnctr-private-ingress-c" }
}

# ==========================================
# Route Tables & Associations
# ==========================================
# Ingress用ルートテーブル
resource "aws_route_table" "ingress" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "sbnctr-rt-ingress" }
}

resource "aws_route_table_association" "ingress_a" {
  subnet_id      = aws_subnet.public_ingress_a.id
  route_table_id = aws_route_table.ingress.id
}

resource "aws_route_table_association" "ingress_c" {
  subnet_id      = aws_subnet.public_ingress_c.id
  route_table_id = aws_route_table.ingress.id
}

# アプリケーション用ルートテーブル
resource "aws_route_table" "app" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "sbnctr-rt-app" }
}

resource "aws_route_table_association" "app_a" {
  subnet_id      = aws_subnet.private_app_a.id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table_association" "app_c" {
  subnet_id      = aws_subnet.private_app_c.id
  route_table_id = aws_route_table.app.id
}

# 管理用ルートテーブル
resource "aws_route_table" "management" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "sbnctr-rt-management" }
}

resource "aws_route_table_association" "management_a" {
  subnet_id      = aws_subnet.public_management_a.id
  route_table_id = aws_route_table.management.id
}

resource "aws_route_table_association" "management_c" {
  subnet_id      = aws_subnet.public_management_c.id
  route_table_id = aws_route_table.management.id
}

# ==========================================
# Security Groups
# ==========================================
# Ingress用SG
resource "aws_security_group" "ingress" {
  name        = "sbnctr-sg-ingress"
  description = "Ingress SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sbnctr-sg-ingress" }
}

# フロントエンド用SG
resource "aws_security_group" "frontend" {
  name        = "sbnctr-sg-frontend"
  description = "Frontend SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.ingress.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sbnctr-sg-frontend" }
}

# バックエンド用SG
resource "aws_security_group" "backend" {
  name        = "sbnctr-sg-backend"
  description = "Backend SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sbnctr-sg-backend" }
}

# DB用SG
resource "aws_security_group" "db" {
  name        = "sbnctr-sg-db"
  description = "DB SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sbnctr-sg-db" }
}

# 管理用SG (インバウンドルールなし)
resource "aws_security_group" "management" {
  name        = "sbnctr-sg-management"
  description = "Management SG"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sbnctr-sg-management" }
}

# Egress用SG
resource "aws_security_group" "egress" {
  name        = "sbnctr-sg-egress"
  description = "Egress SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    security_groups = [
      aws_security_group.frontend.id,
      aws_security_group.backend.id,
      aws_security_group.management.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sbnctr-sg-egress" }
}
