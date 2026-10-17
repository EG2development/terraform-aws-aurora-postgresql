variable "name" {
  description = "Cluster identifier and prefix for every name and Name tag the module creates, for example \"payments-prod\". docs/reference/names-tags-and-iam.md lists every derived name. Changing it replaces the cluster: a new, empty database."
  type        = string
  nullable    = false

  validation {
    # The RDS identifier rules. The longest derived name is the monitoring IAM
    # role "<name>-rds-monitoring", and IAM role names are limited to 64
    # characters.
    condition     = can(regex("^[a-z][a-z0-9-]{0,47}$", var.name)) && !strcontains(var.name, "--") && !endswith(var.name, "-")
    error_message = "name must be 1-48 characters: lowercase letters, digits and hyphens, starting with a letter, without two hyphens in a row and not ending with a hyphen."
  }
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version, for example \"18.4\". Required: a major version is a decision, never a silent default. List the versions a Region offers with `aws rds describe-db-engine-versions --engine aurora-postgresql`. A higher major version needs allow_major_version_upgrade."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)*$", var.engine_version))
    error_message = "engine_version must be an Aurora PostgreSQL version number such as \"18.4\"."
  }
}

variable "vpc_id" {
  description = "ID of the VPC the cluster's security group is created in. It must be the VPC of subnet_ids."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a VPC ID, for example \"vpc-0123456789abcdef0\"."
  }
}

variable "subnet_ids" {
  description = "IDs of the private subnets for the DB subnet group, in at least two Availability Zones. RDS places each instance in one of them."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.subnet_ids) >= 2 && length(var.subnet_ids) == length(distinct(var.subnet_ids))
    error_message = "subnet_ids must list at least two distinct subnets (RDS requires subnets in two Availability Zones)."
  }
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group the module creates. Null (default) uses \"{name}-db-subnet\". Set it only to keep the name of an existing group. Changing it replaces the group and the cluster."
  type        = string
  default     = null

  validation {
    condition     = var.db_subnet_group_name == null ? true : can(regex("^[a-z0-9 ._-]{1,255}$", var.db_subnet_group_name)) && var.db_subnet_group_name != "default"
    error_message = "db_subnet_group_name must be 1-255 lowercase letters, digits, spaces, dots, underscores or hyphens, and not \"default\"."
  }
}

variable "allowed_security_group_ids" {
  description = "Security groups whose members may connect to the database port, as a map of label to security group ID, for example { app = aws_security_group.app.id }. The labels must be known at plan time; the IDs need not be. Each entry becomes one ingress rule, described \"PostgreSQL from {label}\". Default {}: no ingress, add your own rules to the security_group_id output instead."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for label in keys(var.allowed_security_group_ids) : can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$", label))])
    error_message = "Each label in allowed_security_group_ids must be 1-64 letters, digits, dots, underscores or hyphens, starting with a letter or digit."
  }

  validation {
    condition     = alltrue([for id in values(var.allowed_security_group_ids) : can(regex("^sg-[0-9a-f]+$", id))])
    error_message = "Each value in allowed_security_group_ids must be a security group ID, for example \"sg-0123456789abcdef0\"."
  }
}

variable "port" {
  description = "Port the cluster listens on. Default 5432."
  type        = number
  default     = 5432
  nullable    = false

  validation {
    condition     = var.port >= 1150 && var.port <= 65535 && floor(var.port) == var.port
    error_message = "port must be a whole number between 1150 and 65535 (the range Aurora accepts)."
  }
}

variable "database_name" {
  description = "Name of a database to create in the cluster. Null (default) creates none; the built-in \"postgres\" database always exists. Changing it replaces the cluster."
  type        = string
  default     = null

  validation {
    condition     = var.database_name == null ? true : can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.database_name))
    error_message = "database_name must be 1-63 letters, digits or underscores, starting with a letter."
  }
}

variable "master_username" {
  description = "Name of the master database user. Default \"postgres\". Changing it replaces the cluster."
  type        = string
  default     = "postgres"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.master_username))
    error_message = "master_username must be 1-63 letters, digits or underscores, starting with a letter."
  }
}

variable "manage_master_user_password" {
  description = "Let RDS generate the master password, store it in a Secrets Manager secret (master_user_secret_arn output) and rotate it. On by default: the password never appears in Terraform configuration or state. Set false only together with master_password. Turning it on for an existing cluster replaces the current password with a generated one."
  type        = bool
  default     = true
  nullable    = false
}

variable "master_password" {
  description = "Master password, used only when manage_master_user_password is false, and then required. Weakens the default: the value is stored in plain text in Terraform state. At least 8 printable ASCII characters other than /, \" and @. Pass it from a secret store or TF_VAR_master_password, never from a committed file."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.manage_master_user_password ? var.master_password == null : var.master_password != null
    error_message = "Choose one password mode: keep manage_master_user_password = true (default) and leave master_password unset, or set manage_master_user_password = false and supply master_password."
  }

  validation {
    condition     = var.master_password == null ? true : length(var.master_password) >= 8 && can(regex("^[ !#-.0-?A-~]+$", var.master_password))
    error_message = "master_password must be at least 8 printable ASCII characters other than /, \" and @."
  }
}

variable "master_user_secret_kms_key_arn" {
  description = "ARN of a customer managed KMS key that encrypts the RDS-managed master password secret. Null (default) uses the AWS managed key for Secrets Manager. Valid only with manage_master_user_password = true."
  type        = string
  default     = null

  validation {
    condition     = var.master_user_secret_kms_key_arn == null ? true : can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/.+$", var.master_user_secret_kms_key_arn))
    error_message = "master_user_secret_kms_key_arn must be a KMS key ARN, for example \"arn:aws:kms:eu-west-2:111122223333:key/<key-id>\"."
  }

  validation {
    condition     = var.manage_master_user_password ? true : var.master_user_secret_kms_key_arn == null
    error_message = "master_user_secret_kms_key_arn applies only to the managed password secret: leave it unset when manage_master_user_password is false."
  }
}

variable "kms_key_arn" {
  description = "ARN of a customer managed KMS key that encrypts the cluster's storage, snapshots, backups and Performance Insights data. Null (default) uses the AWS managed key for RDS. Storage is always encrypted. Changing it replaces the cluster."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null ? true : can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/.+$", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN, for example \"arn:aws:kms:eu-west-2:111122223333:key/<key-id>\"."
  }
}

variable "iam_database_authentication_enabled" {
  description = "Allow database users granted rds_iam to sign in with short-lived IAM tokens instead of passwords. On by default. Turning it off weakens nothing that is in use, but removes the option of password-free application access."
  type        = bool
  default     = true
  nullable    = false
}

variable "instance_class" {
  description = "Instance class of every instance. \"db.serverless\" (default) is Aurora Serverless v2, scaling between serverlessv2_min_capacity and serverlessv2_max_capacity. A provisioned class such as \"db.r7g.large\" has fixed capacity."
  type        = string
  default     = "db.serverless"
  nullable    = false

  validation {
    condition     = can(regex("^db\\.[a-z0-9-]+(\\.[a-z0-9]+)?$", var.instance_class))
    error_message = "instance_class must be an RDS instance class, for example \"db.serverless\" or \"db.r7g.large\"."
  }
}

variable "instance_count" {
  description = "Number of instances: one writer, and readers for the rest. Default 1. Two or more let Aurora fail over to a reader in a minute or two instead of rebuilding the writer."
  type        = number
  default     = 1
  nullable    = false

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 15 && floor(var.instance_count) == var.instance_count
    error_message = "instance_count must be a whole number from 1 to 15: one writer and up to 14 readers."
  }
}

variable "serverlessv2_min_capacity" {
  description = "Lowest capacity, in Aurora capacity units (ACUs), of each db.serverless instance. Default 0.5. Ignored for provisioned instance classes."
  type        = number
  default     = 0.5
  nullable    = false

  validation {
    condition     = var.serverlessv2_min_capacity >= 0.5 && var.serverlessv2_min_capacity <= 256 && floor(var.serverlessv2_min_capacity * 2) == var.serverlessv2_min_capacity * 2
    error_message = "serverlessv2_min_capacity must be between 0.5 and 256 in steps of 0.5. Scaling to zero (auto-pause) is not supported by this module."
  }
}

variable "serverlessv2_max_capacity" {
  description = "Highest capacity, in ACUs, of each db.serverless instance. Default 16. Ignored for provisioned instance classes."
  type        = number
  default     = 16
  nullable    = false

  validation {
    condition     = var.serverlessv2_max_capacity >= 1 && var.serverlessv2_max_capacity <= 256 && floor(var.serverlessv2_max_capacity * 2) == var.serverlessv2_max_capacity * 2
    error_message = "serverlessv2_max_capacity must be between 1 and 256 in steps of 0.5."
  }

  validation {
    condition     = var.serverlessv2_max_capacity >= var.serverlessv2_min_capacity
    error_message = "serverlessv2_max_capacity must not be lower than serverlessv2_min_capacity."
  }
}

variable "deletion_protection" {
  description = "Refuse to delete the cluster, through Terraform or any other client. On by default. Set false, and apply, before you destroy the cluster on purpose."
  type        = bool
  default     = true
  nullable    = false
}

variable "skip_final_snapshot" {
  description = "Delete the cluster without taking a final snapshot \"{name}-final\". Off by default. Weakens recovery: setting it true means a destroy loses the data for good."
  type        = bool
  default     = false
  nullable    = false
}

variable "backup_retention_period" {
  description = "Days RDS keeps automated backups, for point-in-time recovery. Default 7."
  type        = number
  default     = 7
  nullable    = false

  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35 && floor(var.backup_retention_period) == var.backup_retention_period
    error_message = "backup_retention_period must be a whole number of days from 1 to 35."
  }
}

variable "preferred_backup_window" {
  description = "Daily UTC time range for automated backups, \"hh24:mi-hh24:mi\", at least 30 minutes, for example \"02:00-03:00\". Null (default) lets RDS pick one. Must not overlap preferred_maintenance_window."
  type        = string
  default     = null

  validation {
    condition     = var.preferred_backup_window == null ? true : can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9]$", var.preferred_backup_window))
    error_message = "preferred_backup_window must look like \"02:00-03:00\" (UTC, hh24:mi-hh24:mi)."
  }
}

variable "preferred_maintenance_window" {
  description = "Weekly UTC time range for maintenance, \"ddd:hh24:mi-ddd:hh24:mi\", at least 30 minutes, for example \"sun:04:00-sun:05:00\". Null (default) lets RDS pick one."
  type        = string
  default     = null

  validation {
    condition     = var.preferred_maintenance_window == null ? true : can(regex("^(mon|tue|wed|thu|fri|sat|sun):([01][0-9]|2[0-3]):[0-5][0-9]-(mon|tue|wed|thu|fri|sat|sun):([01][0-9]|2[0-3]):[0-5][0-9]$", var.preferred_maintenance_window))
    error_message = "preferred_maintenance_window must look like \"sun:04:00-sun:05:00\" (UTC, lowercase day names)."
  }
}

variable "enabled_cloudwatch_logs_exports" {
  description = "Log types the cluster exports to CloudWatch Logs. Default [\"postgresql\"], the PostgreSQL server log. Empty exports nothing and weakens incident response. RDS creates the log groups \"/aws/rds/cluster/{name}/{type}\" itself, with no expiry."
  type        = list(string)
  default     = ["postgresql"]
  nullable    = false

  validation {
    condition     = length(var.enabled_cloudwatch_logs_exports) == length(distinct(var.enabled_cloudwatch_logs_exports))
    error_message = "enabled_cloudwatch_logs_exports must not list a log type twice."
  }
}

variable "monitoring_interval" {
  description = "Seconds between enhanced-monitoring samples of each instance: 1, 5, 10, 15, 30 or 60 (default). 0 turns enhanced monitoring off and creates no monitoring role."
  type        = number
  default     = 60
  nullable    = false

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "monitoring_interval must be 0, 1, 5, 10, 15, 30 or 60."
  }
}

variable "performance_insights_enabled" {
  description = "Collect Performance Insights (query load and wait events) on every instance. On by default."
  type        = bool
  default     = true
  nullable    = false
}

variable "auto_minor_version_upgrade" {
  description = "Let RDS apply minor engine versions in the maintenance window. On by default, so security fixes arrive without a change here."
  type        = bool
  default     = true
  nullable    = false
}

variable "allow_major_version_upgrade" {
  description = "Allow a change of engine_version to a higher major version. Off by default; turn it on only for the apply that upgrades, then off again. See docs/how-to/upgrade-the-engine-major-version.md."
  type        = bool
  default     = false
  nullable    = false
}

variable "apply_immediately" {
  description = "Apply cluster changes that need a restart or cause an outage now (true) rather than in the next maintenance window (false). Null (default) leaves the provider's stored value, false for a new cluster. After using true, set false explicitly: going back to null keeps true."
  type        = bool
  default     = null
}

variable "tags" {
  description = "Tags for every resource. The module adds a Name tag to each resource that takes one; a Name key here overrides it everywhere, so it is rarely what you want. Tags from the provider's default_tags apply as usual. Snapshots copy the cluster's tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
