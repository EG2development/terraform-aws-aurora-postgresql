# A production-style cluster: a writer and a reader to fail over to, storage
# and the managed master password encrypted with customer managed keys, fixed
# backup and maintenance windows, ingress from an application security group,
# and an IAM policy that lets the application sign in with IAM database
# authentication, built from the module's outputs.

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  # The account administers the keys; RDS and Secrets Manager use them through
  # grants and on behalf of callers whose IAM policies allow it.
  key_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:${local.partition}:iam::${local.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
    ]
  })
}

resource "aws_kms_key" "storage" {
  description         = "${var.name} Aurora storage, snapshots and backups"
  enable_key_rotation = true
  policy              = local.key_policy
}

resource "aws_kms_key" "master_secret" {
  description         = "${var.name} Aurora master password secret"
  enable_key_rotation = true
  policy              = local.key_policy
}

# Stands in for the security group of your application's tasks or instances.
resource "aws_security_group" "app" {
  name_prefix = "${var.name}-app-"
  description = "Application that connects to the ${var.name} database"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-app" }

  lifecycle {
    create_before_destroy = true
  }
}

# The module creates no egress anywhere; the application needs outbound
# access to the database port.
resource "aws_vpc_security_group_egress_rule" "app_to_database" {
  security_group_id            = aws_security_group.app.id
  description                  = "PostgreSQL to ${var.name}"
  ip_protocol                  = "tcp"
  from_port                    = module.aurora.cluster_port
  to_port                      = module.aurora.cluster_port
  referenced_security_group_id = module.aurora.security_group_id
}

module "aurora" {
  source = "../.."

  name           = var.name
  engine_version = var.engine_version
  vpc_id         = var.vpc_id
  subnet_ids     = var.subnet_ids
  database_name  = "app"

  # A writer and a reader. RDS places each in one of the subnet group's zones;
  # docs/how-to/add-a-reader-for-high-availability.md shows how to check that
  # they differ.
  instance_count            = 2
  serverlessv2_min_capacity = 1
  serverlessv2_max_capacity = 32

  kms_key_arn                    = aws_kms_key.storage.arn
  master_user_secret_kms_key_arn = aws_kms_key.master_secret.arn

  allowed_security_group_ids = { app = aws_security_group.app.id }

  backup_retention_period         = 14
  preferred_backup_window         = "02:00-03:00"
  preferred_maintenance_window    = "sun:04:00-sun:05:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "iam-db-auth-error"]

  tags = {
    Environment = "prod"
    Team        = "payments"
  }
}

# Composition: lets whoever holds this policy sign in as the database user
# var.iam_database_user with an IAM token. Attach it to the application's role,
# and in the database run: CREATE USER <user>; GRANT rds_iam TO <user>;
resource "aws_iam_policy" "connect" {
  name        = "${var.name}-db-connect"
  description = "Sign in to the ${var.name} Aurora cluster as ${var.iam_database_user} with IAM authentication"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "rds-db:connect"
        Resource = "arn:${local.partition}:rds-db:${var.region}:${local.account_id}:dbuser:${module.aurora.cluster_resource_id}/${var.iam_database_user}"
      },
    ]
  })
}
