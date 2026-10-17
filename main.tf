# Resource names are "main" (and "aurora" for the security group) so that a
# caller migrating from an in-repository database module with the same names
# keeps its addresses. Renaming one is a breaking change and needs a moved
# block.

locals {
  db_subnet_group_name = coalesce(var.db_subnet_group_name, "${var.name}-db-subnet")
  serverless           = var.instance_class == "db.serverless"
}

# ---------------------------------------------------------------------------
# Network edge: where the cluster's instances get their addresses, and the one
# security group they use.
# ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name       = local.db_subnet_group_name
  subnet_ids = var.subnet_ids

  tags = merge({ Name = "${local.db_subnet_group_name}-group" }, var.tags)
}

# No inline ingress or egress. Without an egress block the provider removes the
# allow-all egress rule AWS adds to a new group, so the database starts with no
# outbound access: it answers connections and needs nothing else. Callers add
# rules to security_group_id as separate resources.
resource "aws_security_group" "aurora" {
  name_prefix = "${var.name}-aurora-"
  description = "Security group for Aurora PostgreSQL cluster"
  vpc_id      = var.vpc_id

  tags = merge({ Name = "${var.name}-aurora-sg" }, var.tags)

  lifecycle {
    create_before_destroy = true
  }
}

# Optional convenience: one PostgreSQL rule per caller security group. Keyed by
# the caller's static labels, so the set of rules is known at plan time even
# when the group IDs are not.
resource "aws_vpc_security_group_ingress_rule" "allowed" {
  for_each = var.allowed_security_group_ids

  security_group_id            = aws_security_group.aurora.id
  description                  = "PostgreSQL from ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = var.port
  to_port                      = var.port
  referenced_security_group_id = each.value

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Cluster and instances
# ---------------------------------------------------------------------------

resource "aws_rds_cluster" "main" {
  cluster_identifier = var.name
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version
  database_name      = var.database_name
  port               = var.port

  # Exactly one of the two modes, enforced by the master_password validation.
  # Managed: RDS generates the password and keeps it in Secrets Manager, so it
  # never reaches Terraform state. Null rather than false in the other mode,
  # so a cluster that never set the argument sees no change.
  master_username               = var.master_username
  manage_master_user_password   = var.manage_master_user_password ? true : null
  master_user_secret_kms_key_id = var.manage_master_user_password ? var.master_user_secret_kms_key_arn : null
  master_password               = var.manage_master_user_password ? null : var.master_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  storage_encrypted                   = true
  kms_key_id                          = var.kms_key_arn
  iam_database_authentication_enabled = var.iam_database_authentication_enabled
  enabled_cloudwatch_logs_exports     = var.enabled_cloudwatch_logs_exports

  deletion_protection       = var.deletion_protection
  copy_tags_to_snapshot     = true
  backup_retention_period   = var.backup_retention_period
  preferred_backup_window   = var.preferred_backup_window
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final"

  preferred_maintenance_window = var.preferred_maintenance_window
  # Null rather than false when off, so a cluster created without the argument
  # plans no change.
  allow_major_version_upgrade = var.allow_major_version_upgrade ? true : null
  apply_immediately           = var.apply_immediately

  # Capacity range for db.serverless instances. Provisioned instance classes
  # have fixed capacity and take no scaling configuration.
  dynamic "serverlessv2_scaling_configuration" {
    for_each = local.serverless ? [1] : []

    content {
      min_capacity = var.serverlessv2_min_capacity
      max_capacity = var.serverlessv2_max_capacity
    }
  }

  tags = merge({ Name = "${var.name}-aurora-cluster" }, var.tags)
}

# One instance is the writer; the others are readers that Aurora promotes on
# failover. Which instance is the writer changes with each failover: the
# cluster endpoints follow it, the instance names do not.
resource "aws_rds_cluster_instance" "main" {
  count = var.instance_count

  identifier         = "${var.name}-instance-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  monitoring_role_arn          = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  monitoring_interval          = var.monitoring_interval
  performance_insights_enabled = var.performance_insights_enabled
  auto_minor_version_upgrade   = var.auto_minor_version_upgrade
  publicly_accessible          = false

  # Performance Insights holds query text, so the customer managed key that
  # encrypts the data encrypts it too. Null keeps the AWS managed key for RDS.
  performance_insights_kms_key_id = var.performance_insights_enabled ? var.kms_key_arn : null

  tags = merge({ Name = "${var.name}-aurora-instance-${count.index + 1}" }, var.tags)

  # RDS checks the monitoring role's permissions when the instance is created,
  # so the policy must be attached first.
  depends_on = [aws_iam_role_policy_attachment.rds_monitoring]
}
