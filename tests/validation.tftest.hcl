# Every validation rejects bad input at plan time, before any API call.

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
}

run "accepts_valid_input" {
  command = plan
}

run "accepts_own_password_mode" {
  command = plan
  variables {
    manage_master_user_password = false
    master_password             = "not-a-real-password-1"
  }
}

# name

run "rejects_name_with_uppercase" {
  command = plan
  variables {
    name = "Example"
  }
  expect_failures = [var.name]
}

run "rejects_name_starting_with_digit" {
  command = plan
  variables {
    name = "1example"
  }
  expect_failures = [var.name]
}

run "rejects_name_with_double_hyphen" {
  command = plan
  variables {
    name = "my--db"
  }
  expect_failures = [var.name]
}

run "rejects_name_ending_with_hyphen" {
  command = plan
  variables {
    name = "mydb-"
  }
  expect_failures = [var.name]
}

run "rejects_name_too_long_for_iam" {
  command = plan
  variables {
    name = "a234567890123456789012345678901234567890123456789"
  }
  expect_failures = [var.name]
}

# Engine and network

run "rejects_engine_version_that_is_not_a_number" {
  command = plan
  variables {
    engine_version = "latest"
  }
  expect_failures = [var.engine_version]
}

run "rejects_invalid_vpc_id" {
  command = plan
  variables {
    vpc_id = "my-vpc"
  }
  expect_failures = [var.vpc_id]
}

run "rejects_single_subnet" {
  command = plan
  variables {
    subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1"]
  }
  expect_failures = [var.subnet_ids]
}

run "rejects_duplicate_subnets" {
  command = plan
  variables {
    subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0aaaaaaaaaaaaaaa1"]
  }
  expect_failures = [var.subnet_ids]
}

run "rejects_uppercase_db_subnet_group_name" {
  command = plan
  variables {
    db_subnet_group_name = "My-Group"
  }
  expect_failures = [var.db_subnet_group_name]
}

run "rejects_default_db_subnet_group_name" {
  command = plan
  variables {
    db_subnet_group_name = "default"
  }
  expect_failures = [var.db_subnet_group_name]
}

run "rejects_invalid_security_group_label" {
  command = plan
  variables {
    allowed_security_group_ids = { "my app!" = "sg-0123456789abcdef0" }
  }
  expect_failures = [var.allowed_security_group_ids]
}

run "rejects_invalid_security_group_id" {
  command = plan
  variables {
    allowed_security_group_ids = { app = "app-sg" }
  }
  expect_failures = [var.allowed_security_group_ids]
}

run "rejects_port_below_aurora_range" {
  command = plan
  variables {
    port = 80
  }
  expect_failures = [var.port]
}

# Database and credentials

run "rejects_invalid_database_name" {
  command = plan
  variables {
    database_name = "my-db"
  }
  expect_failures = [var.database_name]
}

run "rejects_invalid_master_username" {
  command = plan
  variables {
    master_username = "1admin"
  }
  expect_failures = [var.master_username]
}

run "rejects_password_with_managed_password" {
  command = plan
  variables {
    master_password = "not-a-real-password-1"
  }
  expect_failures = [var.master_password]
}

run "rejects_unmanaged_mode_without_password" {
  command = plan
  variables {
    manage_master_user_password = false
  }
  expect_failures = [var.master_password]
}

run "rejects_short_password" {
  command = plan
  variables {
    manage_master_user_password = false
    master_password             = "short"
  }
  expect_failures = [var.master_password]
}

run "rejects_password_with_forbidden_character" {
  command = plan
  variables {
    manage_master_user_password = false
    master_password             = "not-a-real@password"
  }
  expect_failures = [var.master_password]
}

run "rejects_secret_key_that_is_not_an_arn" {
  command = plan
  variables {
    master_user_secret_kms_key_arn = "alias/rds-secrets"
  }
  expect_failures = [var.master_user_secret_kms_key_arn]
}

run "rejects_secret_key_without_managed_password" {
  command = plan
  variables {
    manage_master_user_password    = false
    master_password                = "not-a-real-password-1"
    master_user_secret_kms_key_arn = "arn:aws:kms:eu-west-2:111122223333:key/00000000-0000-0000-0000-000000000002"
  }
  expect_failures = [var.master_user_secret_kms_key_arn]
}

run "rejects_storage_key_alias" {
  command = plan
  variables {
    kms_key_arn = "arn:aws:kms:eu-west-2:111122223333:alias/aws/rds"
  }
  expect_failures = [var.kms_key_arn]
}

# Instances and capacity

run "rejects_invalid_instance_class" {
  command = plan
  variables {
    instance_class = "r7g.large"
  }
  expect_failures = [var.instance_class]
}

run "rejects_zero_instances" {
  command = plan
  variables {
    instance_count = 0
  }
  expect_failures = [var.instance_count]
}

run "rejects_too_many_instances" {
  command = plan
  variables {
    instance_count = 16
  }
  expect_failures = [var.instance_count]
}

run "rejects_auto_pause_to_zero" {
  command = plan
  variables {
    serverlessv2_min_capacity = 0
  }
  expect_failures = [var.serverlessv2_min_capacity]
}

run "rejects_capacity_off_the_half_step" {
  command = plan
  variables {
    serverlessv2_min_capacity = 0.75
  }
  expect_failures = [var.serverlessv2_min_capacity]
}

run "rejects_max_capacity_above_256" {
  command = plan
  variables {
    serverlessv2_max_capacity = 512
  }
  expect_failures = [var.serverlessv2_max_capacity]
}

run "rejects_max_capacity_below_min" {
  command = plan
  variables {
    serverlessv2_min_capacity = 8
    serverlessv2_max_capacity = 4
  }
  expect_failures = [var.serverlessv2_max_capacity]
}

# Backups, maintenance, logs and monitoring

run "rejects_zero_backup_retention" {
  command = plan
  variables {
    backup_retention_period = 0
  }
  expect_failures = [var.backup_retention_period]
}

run "rejects_backup_retention_over_35_days" {
  command = plan
  variables {
    backup_retention_period = 36
  }
  expect_failures = [var.backup_retention_period]
}

run "rejects_malformed_backup_window" {
  command = plan
  variables {
    preferred_backup_window = "2am-3am"
  }
  expect_failures = [var.preferred_backup_window]
}

run "rejects_malformed_maintenance_window" {
  command = plan
  variables {
    preferred_maintenance_window = "Sunday 04:00"
  }
  expect_failures = [var.preferred_maintenance_window]
}

run "rejects_duplicate_log_type" {
  command = plan
  variables {
    enabled_cloudwatch_logs_exports = ["postgresql", "postgresql"]
  }
  expect_failures = [var.enabled_cloudwatch_logs_exports]
}

run "rejects_unsupported_monitoring_interval" {
  command = plan
  variables {
    monitoring_interval = 20
  }
  expect_failures = [var.monitoring_interval]
}
