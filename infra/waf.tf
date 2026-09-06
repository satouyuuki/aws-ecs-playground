# ==========================================
# AWS WAF CloudWatch Logs Group
# ==========================================
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "aws-waf-logs-${local.prefix}-frontend-app"
  retention_in_days = 14
  log_group_class   = "STANDARD"

  tags = {
    Name = "aws-waf-logs-${local.prefix}-frontend-app"
  }
}

# ==========================================
# AWS WAF Web ACL (Security Design & Managed Rules)
# ==========================================
resource "aws_wafv2_web_acl" "frontend_waf" {
  name        = "${local.prefix}-frontend-app-waf"
  description = "WAF for frontend app protection"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.prefix}-frontend-app-waf"
    sampled_requests_enabled   = true
  }

  # 1. カスタムルール：ジオロケーションチェック (日本以外からのアクセスをブロック)
  rule {
    name     = "GeoLocationCheck"
    priority = 1

    action {
      block {}
    }

    statement {
      not_statement {
        statement {
          geo_match_statement {
            country_codes = ["JP"]
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockNonJapanAccess"
      sampled_requests_enabled   = true
    }
  }

  # 2. Amazon IP 評価リスト (AWSManagedRulesAmazonIpReputationList)
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  # 3. 匿名 IP リスト (AWSManagedRulesAnonymousIpList)
  rule {
    name     = "AWSManagedRulesAnonymousIpList"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAnonymousIpList"
      sampled_requests_enabled   = true
    }
  }

  # 4. コアルール (AWSManagedRulesCommonRuleSet)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # 5. 不正なインプットデータに関するルール (AWSManagedRulesKnownBadInputsRuleSet)
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # 6. SQLインジェクションに関するルール (AWSManagedRulesSQLiRuleSet)
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 6

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # 7. Linux固有の攻撃に対するルール (AWSManagedRulesLinuxRuleSet)
  rule {
    name     = "AWSManagedRulesLinuxRuleSet"
    priority = 7

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesLinuxRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # 8. POSIX固有の攻撃に対応するルール (AWSManagedRulesUnixRuleSet)
  rule {
    name     = "AWSManagedRulesUnixRuleSet"
    priority = 8

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesUnixRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesUnixRuleSet"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name = "${local.prefix}-frontend-app"
  }
}

# ==========================================
# WAF Logging Configuration
# ==========================================
resource "aws_wafv2_web_acl_logging_configuration" "frontend_waf_logging" {
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.frontend_waf.arn
}

# ==========================================
# Associate WAF with ALB (Ingress)
# ==========================================
resource "aws_wafv2_web_acl_association" "alb_association" {
  resource_arn = aws_lb.ingress.arn
  web_acl_arn  = aws_wafv2_web_acl.frontend_waf.arn
}
