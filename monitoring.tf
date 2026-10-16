# Enhanced monitoring: RDS publishes operating-system metrics of each instance
# to CloudWatch Logs through this role. Only the RDS monitoring service, acting
# for a DB instance in this account and Region, can assume it, and it holds
# only the AWS managed policy made for that purpose.

data "aws_partition" "current" {
  count = var.monitoring_interval > 0 ? 1 : 0
}

data "aws_caller_identity" "current" {
  count = var.monitoring_interval > 0 ? 1 : 0
}

data "aws_region" "current" {
  count = var.monitoring_interval > 0 ? 1 : 0
}

resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name = "${var.name}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
        # Confused-deputy protection: only on behalf of DB instances in this
        # account and Region.
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current[0].account_id }
          ArnLike = {
            "aws:SourceArn" = "arn:${data.aws_partition.current[0].partition}:rds:${data.aws_region.current[0].region}:${data.aws_caller_identity.current[0].account_id}:db:*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:${data.aws_partition.current[0].partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
