# An existing caller that sets its own master password, rendered exactly as
# the in-repository database module it replaces rendered it. Every name here is
# a compatibility contract: a change to one replaces or renames a caller's
# resources, which is a major release.

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
    defaults = { arn = "arn:aws:iam::111122223333:role/example-prod-rds-monitoring" }
  }
}

variables {
  name                        = "example-prod"
  engine_version              = "18.4"
  vpc_id                      = "vpc-0123456789abcdef0"
  subnet_ids                  = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  database_name               = "app_db"
  master_username             = "appadmin"
  manage_master_user_password = false
  master_password             = "not-a-real-password-1"
  deletion_protection         = true
  skip_final_snapshot         = false
  preferred_backup_window     = "02:00-03:00"
  tags                        = { Project = "example", Environment = "prod", ManagedBy = "terraform" }
}

run "names_and_tags_are_stable" {
  command = plan

  assert {
    condition = (
      aws_rds_cluster.main.cluster_identifier == "example-prod" &&
      aws_rds_cluster.main.final_snapshot_identifier == "example-prod-final" &&
      aws_rds_cluster.main.tags == tomap({ Name = "example-prod-aurora-cluster", Project = "example", Environment = "prod", ManagedBy = "terraform" })
    )
    error_message = "Cluster identifier, final snapshot name or cluster tags changed."
  }

  assert {
    condition = (
      length(aws_rds_cluster_instance.main) == 1 &&
      aws_rds_cluster_instance.main[0].identifier == "example-prod-instance-1" &&
      aws_rds_cluster_instance.main[0].tags == tomap({ Name = "example-prod-aurora-instance-1", Project = "example", Environment = "prod", ManagedBy = "terraform" })
    )
    error_message = "Instance identifier or tags changed."
  }

  assert {
    condition = (
      aws_security_group.aurora.name_prefix == "example-prod-aurora-" &&
      aws_security_group.aurora.description == "Security group for Aurora PostgreSQL cluster" &&
      aws_security_group.aurora.tags == tomap({ Name = "example-prod-aurora-sg", Project = "example", Environment = "prod", ManagedBy = "terraform" })
    )
    error_message = "Security group name prefix, description (a change forces replacement) or tags changed."
  }

  assert {
    condition = (
      aws_db_subnet_group.main.name == "example-prod-db-subnet" &&
      aws_rds_cluster.main.db_subnet_group_name == "example-prod-db-subnet" &&
      aws_db_subnet_group.main.tags == tomap({ Name = "example-prod-db-subnet-group", Project = "example", Environment = "prod", ManagedBy = "terraform" })
    )
    error_message = "DB subnet group name or tags changed."
  }

  assert {
    condition = (
      aws_iam_role.rds_monitoring[0].name == "example-prod-rds-monitoring" &&
      aws_iam_role.rds_monitoring[0].tags == tomap({ Project = "example", Environment = "prod", ManagedBy = "terraform" }) &&
      jsondecode(aws_iam_role.rds_monitoring[0].assume_role_policy).Statement[0].Principal.Service == "monitoring.rds.amazonaws.com"
    )
    error_message = "Monitoring role name, tags or trust policy changed."
  }
}

run "settings_are_unchanged" {
  command = plan

  assert {
    condition = (
      aws_rds_cluster.main.engine == "aurora-postgresql" &&
      aws_rds_cluster.main.engine_version == "18.4" &&
      aws_rds_cluster.main.database_name == "app_db" &&
      aws_rds_cluster.main.master_username == "appadmin"
    )
    error_message = "Engine, version, database name or master user changed."
  }

  assert {
    condition     = aws_rds_cluster.main.manage_master_user_password == null && nonsensitive(aws_rds_cluster.main.master_password) == "not-a-real-password-1"
    error_message = "With manage_master_user_password = false the cluster takes master_password, and manage_master_user_password is null (never false), so a cluster that never set it sees no change."
  }

  assert {
    condition = (
      length(aws_rds_cluster.main.serverlessv2_scaling_configuration) == 1 &&
      aws_rds_cluster.main.serverlessv2_scaling_configuration[0].min_capacity == 0.5 &&
      aws_rds_cluster.main.serverlessv2_scaling_configuration[0].max_capacity == 16
    )
    error_message = "Serverless v2 capacity must stay 0.5-16 ACUs."
  }

  assert {
    condition = (
      aws_rds_cluster.main.storage_encrypted == true &&
      aws_rds_cluster.main.iam_database_authentication_enabled == true &&
      aws_rds_cluster.main.deletion_protection == true &&
      aws_rds_cluster.main.copy_tags_to_snapshot == true &&
      aws_rds_cluster.main.skip_final_snapshot == false &&
      aws_rds_cluster.main.backup_retention_period == 7 &&
      aws_rds_cluster.main.preferred_backup_window == "02:00-03:00" &&
      aws_rds_cluster.main.enabled_cloudwatch_logs_exports == toset(["postgresql"])
    )
    error_message = "Encryption, IAM authentication, deletion protection, snapshots, backups or log exports changed."
  }

  assert {
    condition = (
      aws_rds_cluster_instance.main[0].instance_class == "db.serverless" &&
      aws_rds_cluster_instance.main[0].monitoring_interval == 60 &&
      aws_rds_cluster_instance.main[0].performance_insights_enabled == true &&
      aws_rds_cluster_instance.main[0].auto_minor_version_upgrade == true &&
      aws_rds_cluster_instance.main[0].publicly_accessible == false
    )
    error_message = "Instance class, monitoring, Performance Insights, minor upgrades or public access changed."
  }
}

run "no_secret_without_managed_password" {
  command = apply

  assert {
    condition     = output.master_user_secret_arn == null
    error_message = "master_user_secret_arn is null when RDS does not manage the password."
  }

  assert {
    condition     = aws_rds_cluster_instance.main[0].monitoring_role_arn == aws_iam_role.rds_monitoring[0].arn
    error_message = "The instance must use the role named example-prod-rds-monitoring."
  }
}
