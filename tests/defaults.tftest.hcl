# What a caller gets from the required inputs alone. These assertions pin the
# secure defaults; a change to any of them changes existing callers'
# infrastructure, which is a major release.
# The provider is mocked: no credentials, nothing created.

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
  subnet_ids     = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  tags           = { Team = "platform" }
}

run "master_password_is_managed_by_rds" {
  command = plan

  assert {
    condition     = aws_rds_cluster.main.manage_master_user_password == true && aws_rds_cluster.main.master_password == null
    error_message = "By default RDS must manage the master password, and Terraform must not set one."
  }

  assert {
    condition     = aws_rds_cluster.main.master_username == "postgres"
    error_message = "The master user is \"postgres\" by default."
  }
}

run "storage_and_access_are_locked_down" {
  command = apply

  assert {
    condition     = aws_rds_cluster.main.storage_encrypted == true && aws_rds_cluster.main.iam_database_authentication_enabled == true
    error_message = "Storage must be encrypted and IAM database authentication on."
  }

  assert {
    condition     = aws_rds_cluster.main.vpc_security_group_ids == toset([aws_security_group.aurora.id]) && aws_rds_cluster.main.db_subnet_group_name == "example-db-subnet"
    error_message = "The cluster must use only the module's security group and subnet group."
  }

  assert {
    condition     = alltrue([for i in aws_rds_cluster_instance.main : i.publicly_accessible == false])
    error_message = "No instance may be publicly accessible."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.allowed) == 0
    error_message = "No ingress is allowed unless the caller asks for it."
  }

  assert {
    condition     = aws_rds_cluster.main.port == 5432 && aws_security_group.aurora.vpc_id == "vpc-0123456789abcdef0"
    error_message = "The cluster listens on 5432 and its security group is in vpc_id."
  }

  assert {
    condition     = aws_db_subnet_group.main.subnet_ids == toset(["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"])
    error_message = "The subnet group must contain subnet_ids."
  }
}

run "data_survives_mistakes" {
  command = plan

  assert {
    condition     = aws_rds_cluster.main.deletion_protection == true
    error_message = "Deletion protection must be on by default."
  }

  assert {
    condition     = aws_rds_cluster.main.skip_final_snapshot == false && aws_rds_cluster.main.final_snapshot_identifier == "example-final"
    error_message = "A destroy must leave a final snapshot named <name>-final."
  }

  assert {
    condition     = aws_rds_cluster.main.backup_retention_period == 7 && aws_rds_cluster.main.copy_tags_to_snapshot == true
    error_message = "Backups are kept for 7 days and snapshots carry the cluster's tags."
  }

  assert {
    condition     = aws_rds_cluster.main.allow_major_version_upgrade == null
    error_message = "Major version upgrades must be refused unless allowed for one apply."
  }
}

run "serverless_v2_with_one_instance" {
  command = plan

  assert {
    condition     = aws_rds_cluster.main.engine == "aurora-postgresql" && aws_rds_cluster.main.engine_version == "18.4"
    error_message = "The cluster runs aurora-postgresql at engine_version."
  }

  assert {
    condition = (
      length(aws_rds_cluster.main.serverlessv2_scaling_configuration) == 1 &&
      aws_rds_cluster.main.serverlessv2_scaling_configuration[0].min_capacity == 0.5 &&
      aws_rds_cluster.main.serverlessv2_scaling_configuration[0].max_capacity == 16
    )
    error_message = "Serverless v2 scales between 0.5 and 16 ACUs by default."
  }

  assert {
    condition = (
      length(aws_rds_cluster_instance.main) == 1 &&
      aws_rds_cluster_instance.main[0].instance_class == "db.serverless" &&
      aws_rds_cluster_instance.main[0].engine == "aurora-postgresql" &&
      aws_rds_cluster_instance.main[0].engine_version == "18.4"
    )
    error_message = "One db.serverless instance on the cluster's engine and version."
  }
}

run "observability_is_on" {
  command = plan

  assert {
    condition     = aws_rds_cluster.main.enabled_cloudwatch_logs_exports == toset(["postgresql"])
    error_message = "The PostgreSQL log must be exported to CloudWatch Logs."
  }

  assert {
    condition = (
      aws_rds_cluster_instance.main[0].monitoring_interval == 60 &&
      aws_rds_cluster_instance.main[0].performance_insights_enabled == true &&
      aws_rds_cluster_instance.main[0].auto_minor_version_upgrade == true
    )
    error_message = "Enhanced monitoring every 60 s, Performance Insights and automatic minor upgrades are on."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.rds_monitoring[0].assume_role_policy).Statement[0].Principal.Service == "monitoring.rds.amazonaws.com" &&
      jsondecode(aws_iam_role.rds_monitoring[0].assume_role_policy).Statement[0].Action == "sts:AssumeRole" &&
      length(jsondecode(aws_iam_role.rds_monitoring[0].assume_role_policy).Statement) == 1 &&
      jsondecode(aws_iam_role.rds_monitoring[0].assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == "111122223333" &&
      jsondecode(aws_iam_role.rds_monitoring[0].assume_role_policy).Statement[0].Condition.ArnLike["aws:SourceArn"] == "arn:aws:rds:eu-west-2:111122223333:db:*"
    )
    error_message = "Only the RDS monitoring service, acting for DB instances in this account and Region, may assume the monitoring role."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.rds_monitoring[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
    error_message = "The monitoring role holds only the AWS managed enhanced-monitoring policy."
  }
}

run "outputs_are_wired" {
  command = apply

  assert {
    condition     = aws_rds_cluster_instance.main[0].monitoring_role_arn == aws_iam_role.rds_monitoring[0].arn
    error_message = "Instances must use the module's monitoring role."
  }

  assert {
    condition = (
      output.cluster_identifier == aws_rds_cluster.main.cluster_identifier &&
      output.cluster_arn == aws_rds_cluster.main.arn &&
      output.cluster_resource_id == aws_rds_cluster.main.cluster_resource_id &&
      output.cluster_endpoint == aws_rds_cluster.main.endpoint &&
      output.cluster_reader_endpoint == aws_rds_cluster.main.reader_endpoint &&
      output.cluster_port == 5432
    )
    error_message = "Cluster outputs must come from the cluster."
  }

  assert {
    condition = (
      output.security_group_id == aws_security_group.aurora.id &&
      output.db_subnet_group_name == "example-db-subnet" &&
      output.instance_identifiers == ["example-instance-1"] &&
      output.master_username == "postgres"
    )
    error_message = "Security group, subnet group, instance and user outputs are wrong."
  }
}
