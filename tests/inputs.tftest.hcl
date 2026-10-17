# Optional inputs change only what they say.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111122223333" }
  }
  mock_data "aws_region" {
    defaults = { region = "eu-west-2" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  # The provider checks that this is an ARN, so the mock must return an ARN-shaped value.
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::111122223333:role/example-rds-monitoring" }
  }
}

variables {
  name           = "example"
  engine_version = "18.4"
  vpc_id         = "vpc-0123456789abcdef0"
  subnet_ids     = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2", "subnet-0ccccccccccccccc3"]
}

run "allowed_security_groups_get_one_rule_each" {
  command = plan

  variables {
    port = 6432
    allowed_security_group_ids = {
      app                = "sg-0123456789abcdef0"
      "ingestion-lambda" = "sg-0fedcba9876543210"
    }
  }

  assert {
    condition     = keys(aws_vpc_security_group_ingress_rule.allowed) == ["app", "ingestion-lambda"]
    error_message = "One ingress rule per allowed_security_group_ids entry, keyed by label."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.allowed["app"].referenced_security_group_id == "sg-0123456789abcdef0" &&
      aws_vpc_security_group_ingress_rule.allowed["app"].description == "PostgreSQL from app" &&
      aws_vpc_security_group_ingress_rule.allowed["app"].ip_protocol == "tcp" &&
      aws_vpc_security_group_ingress_rule.allowed["app"].from_port == 6432 &&
      aws_vpc_security_group_ingress_rule.allowed["app"].to_port == 6432 &&
      aws_vpc_security_group_ingress_rule.allowed["ingestion-lambda"].description == "PostgreSQL from ingestion-lambda"
    )
    error_message = "Each rule admits TCP on the cluster port from one security group and names its label."
  }

  assert {
    condition     = aws_rds_cluster.main.port == 6432
    error_message = "port sets the cluster port."
  }
}

run "provisioned_instances_take_no_scaling_configuration" {
  command = plan

  variables {
    instance_class = "db.r7g.large"
    instance_count = 2
  }

  assert {
    condition     = length(aws_rds_cluster.main.serverlessv2_scaling_configuration) == 0
    error_message = "A provisioned instance class has no Serverless v2 scaling configuration."
  }

  assert {
    condition = (
      [for i in aws_rds_cluster_instance.main : i.instance_class] == ["db.r7g.large", "db.r7g.large"] &&
      [for i in aws_rds_cluster_instance.main : i.identifier] == ["example-instance-1", "example-instance-2"] &&
      aws_rds_cluster_instance.main[1].tags["Name"] == "example-aurora-instance-2"
    )
    error_message = "instance_count instances of instance_class, numbered from 1."
  }
}

run "serverless_capacity" {
  command = plan

  variables {
    serverlessv2_min_capacity = 2
    serverlessv2_max_capacity = 64.5
  }

  assert {
    condition = (
      aws_rds_cluster.main.serverlessv2_scaling_configuration[0].min_capacity == 2 &&
      aws_rds_cluster.main.serverlessv2_scaling_configuration[0].max_capacity == 64.5
    )
    error_message = "The capacity inputs reach the scaling configuration."
  }
}

run "monitoring_off" {
  command = plan

  variables {
    monitoring_interval = 0
  }

  assert {
    condition = (
      length(aws_iam_role.rds_monitoring) == 0 &&
      length(aws_iam_role_policy_attachment.rds_monitoring) == 0 &&
      length(data.aws_partition.current) == 0 &&
      aws_rds_cluster_instance.main[0].monitoring_interval == 0
    )
    error_message = "monitoring_interval = 0 must create no monitoring role and make no lookup for it."
  }
}

run "encryption_keys" {
  command = plan

  variables {
    kms_key_arn                    = "arn:aws:kms:eu-west-2:111122223333:key/00000000-0000-0000-0000-000000000001"
    master_user_secret_kms_key_arn = "arn:aws:kms:eu-west-2:111122223333:key/00000000-0000-0000-0000-000000000002"
  }

  assert {
    condition = (
      aws_rds_cluster.main.kms_key_id == "arn:aws:kms:eu-west-2:111122223333:key/00000000-0000-0000-0000-000000000001" &&
      aws_rds_cluster.main.master_user_secret_kms_key_id == "arn:aws:kms:eu-west-2:111122223333:key/00000000-0000-0000-0000-000000000002" &&
      aws_rds_cluster.main.storage_encrypted == true &&
      aws_rds_cluster_instance.main[0].performance_insights_kms_key_id == "arn:aws:kms:eu-west-2:111122223333:key/00000000-0000-0000-0000-000000000001"
    )
    error_message = "kms_key_arn encrypts storage and Performance Insights; master_user_secret_kms_key_arn encrypts the managed secret."
  }
}

run "windows_and_upgrades" {
  command = plan

  variables {
    backup_retention_period      = 35
    preferred_backup_window      = "01:00-01:30"
    preferred_maintenance_window = "sun:04:00-sun:05:00"
    allow_major_version_upgrade  = true
    apply_immediately            = true
    auto_minor_version_upgrade   = false
  }

  assert {
    condition = (
      aws_rds_cluster.main.backup_retention_period == 35 &&
      aws_rds_cluster.main.preferred_backup_window == "01:00-01:30" &&
      aws_rds_cluster.main.preferred_maintenance_window == "sun:04:00-sun:05:00" &&
      aws_rds_cluster.main.allow_major_version_upgrade == true &&
      aws_rds_cluster.main.apply_immediately == true &&
      aws_rds_cluster_instance.main[0].auto_minor_version_upgrade == false
    )
    error_message = "Backup, maintenance and upgrade inputs must reach the cluster and instances."
  }
}

run "weakened_defaults_do_what_they_say" {
  command = plan

  variables {
    deletion_protection                 = false
    skip_final_snapshot                 = true
    iam_database_authentication_enabled = false
    performance_insights_enabled        = false
    enabled_cloudwatch_logs_exports     = ["postgresql", "iam-db-auth-error"]
  }

  assert {
    condition = (
      aws_rds_cluster.main.deletion_protection == false &&
      aws_rds_cluster.main.skip_final_snapshot == true &&
      aws_rds_cluster.main.final_snapshot_identifier == null &&
      aws_rds_cluster.main.iam_database_authentication_enabled == false &&
      aws_rds_cluster_instance.main[0].performance_insights_enabled == false &&
      aws_rds_cluster.main.enabled_cloudwatch_logs_exports == toset(["postgresql", "iam-db-auth-error"])
    )
    error_message = "Each weakening input must change only its own setting."
  }

  assert {
    condition     = aws_rds_cluster.main.storage_encrypted == true && aws_rds_cluster_instance.main[0].publicly_accessible == false
    error_message = "Encryption and private access are not configurable."
  }
}

run "subnet_group_and_database_names" {
  command = plan

  variables {
    db_subnet_group_name = "legacy-db-subnets"
    database_name        = "orders"
    master_username      = "dbadmin"
    tags                 = { Team = "payments" }
  }

  assert {
    condition = (
      aws_db_subnet_group.main.name == "legacy-db-subnets" &&
      aws_db_subnet_group.main.tags == tomap({ Name = "legacy-db-subnets-group", Team = "payments" }) &&
      aws_rds_cluster.main.db_subnet_group_name == "legacy-db-subnets"
    )
    error_message = "db_subnet_group_name names the group, and its Name tag is <group name>-group."
  }

  assert {
    condition     = aws_rds_cluster.main.database_name == "orders" && aws_rds_cluster.main.master_username == "dbadmin"
    error_message = "database_name and master_username reach the cluster."
  }
}

run "caller_name_tag_wins" {
  command = plan

  variables {
    tags = { Name = "shared-name" }
  }

  assert {
    condition     = aws_rds_cluster.main.tags["Name"] == "shared-name" && aws_security_group.aurora.tags["Name"] == "shared-name"
    error_message = "A Name key in var.tags overrides the generated Name tag."
  }
}
