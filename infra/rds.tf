# ==========================================
# RDS DB Subnet Group
# ==========================================
resource "aws_db_subnet_group" "main" {
  name        = "${local.prefix}-main"
  description = "DB subnet group for ${local.prefix}"
  subnet_ids  = [aws_subnet.private_db_a.id, aws_subnet.private_db_c.id]

  tags = {
    Name = "${local.prefix}-main"
  }
}

# ==========================================
# Aurora PostgreSQL Cluster (Serverless v2 with Secrets Manager)
# ==========================================
resource "aws_rds_cluster" "postgresql" {
  cluster_identifier = "${local.prefix}-db-cluster"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = "17.7"
  database_name      = "app"
  master_username    = "${local.prefix}admin"

  # パスワードの代わりにSecrets Manager管理を使用
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  port                   = 5432

  # コストがかかるオプション・不要な機能をOFF
  storage_encrypted               = true
  skip_final_snapshot             = true
  deletion_protection             = false
  enabled_cloudwatch_logs_exports = []
  enable_http_endpoint            = true # RDS Data APIの有効化

  serverlessv2_scaling_configuration {
    min_capacity = 0
    max_capacity = 1.0
  }

  tags = {
    Name = "${local.prefix}-db-cluster"
  }
}

# Aurora Serverless v2 インスタンス (AZ: 1aに配置)
resource "aws_rds_cluster_instance" "postgresql_instance" {
  identifier         = "${local.prefix}-db-instance-1a"
  cluster_identifier = aws_rds_cluster.postgresql.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.postgresql.engine
  engine_version     = aws_rds_cluster.postgresql.engine_version
  availability_zone  = "ap-northeast-1a"

  publicly_accessible = false

  tags = {
    Name = "${local.prefix}-db-instance-1a"
  }
}
