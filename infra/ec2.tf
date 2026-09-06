# ==========================================
# Pseudo Cloud9 (Development EC2)
# ==========================================

# 1. IAM Role
resource "aws_iam_role" "pseudo_cloud9" {
  name = "sbnctr-pseudo-cloud9-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  ]

  inline_policy {
    name = "ECSServiceUpdatePolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ecs:UpdateService",
            "ecs:DescribeServices",
            "ecs:DescribeClusters",
            "ecs:ListServices",
            "ecs:ListClusters",
            "ecs:ListTasks",
            "ecs:DescribeTasks",
            "ecs:ExecuteCommand"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ssm:StartSession"
          ]
          Resource = [
            "arn:aws:ssm:ap-northeast-1:${data.aws_caller_identity.current.account_id}:document/AmazonECS-ExecuteInteractiveCommand",
            "arn:aws:ecs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:task/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "iam:PassRole"
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "iam:PassedToService" : "ecs-tasks.amazonaws.com"
            }
          }
        }
      ]
    })
  }

  tags = {
    Name = "sbnctr-pseudo-cloud9-role"
  }
}

# アカウントID動的取得用のデータソース
data "aws_caller_identity" "current" {}

# 2. IAM Instance Profile
resource "aws_iam_instance_profile" "instance_profile" {
  name = "sbnctr-pseudo-cloud9-instance-profile"
  role = aws_iam_role.pseudo_cloud9.name
}

# 3. EC2 Instance (Pseudo Cloud9)
resource "aws_instance" "pseudo_cloud9" {
  ami                         = "ami-0976ced58148ef3eb"
  instance_type               = "t4g.small"
  subnet_id                   = aws_subnet.public_management_c.id # 管理用予備(ap-northeast-1c)
  vpc_security_group_ids      = [aws_security_group.management.id]
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    
    # k6スクリプトを作成
    cat > /home/ec2-user/load-test.js << 'EOF_K6'
    import http from 'k6/http';
    import { check } from 'k6';

    const TARGET_URL = __ENV.TARGET_URL || 'http://backend-app.${local.prefix}.local:8081/';
    const VUS = __ENV.VUS ? parseInt(__ENV.VUS) : 100;
    const ITERATIONS = __ENV.ITERATIONS ? parseInt(__ENV.ITERATIONS) : 1000000;

    export const options = ITERATIONS ? {
      // 固定回数実行の設定
      vus: VUS,
      iterations: ITERATIONS,
    } : {
      // 時間ベース実行の設定
      vus: VUS,
      duration: __ENV.DURATION || '10m',
    };

    export default function () {
      const response = http.get(TARGET_URL);

      check(response, {
        'ステータスコードが200': (r) => r.status === 200,
        'レスポンスタイムが3秒以内': (r) => r.timings.duration < 3000,
      });
    }
    EOF_K6
    
    # ファイルの所有者を設定
    chown ec2-user:ec2-user /home/ec2-user/load-test.js
  EOF

  tags = {
    Name = "sbnctr-pseudo-cloud9"
  }
}

