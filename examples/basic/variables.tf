variable "region" {
  description = "AWS Region to create the cluster in."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Cluster identifier and name prefix."
  type        = string
  default     = "example"
}

variable "engine_version" {
  description = "Aurora PostgreSQL version. List the versions your Region offers with `aws rds describe-db-engine-versions --engine aurora-postgresql`."
  type        = string
  default     = "18.4"
}

variable "vpc_id" {
  description = "ID of the VPC that holds subnet_ids."
  type        = string
}

variable "subnet_ids" {
  description = "IDs of two or more private subnets in different Availability Zones."
  type        = list(string)
}
