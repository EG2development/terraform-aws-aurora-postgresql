output "cluster_identifier" {
  description = "Identifier of the cluster (the DBClusterIdentifier dimension of its CloudWatch metrics)."
  value       = aws_rds_cluster.main.cluster_identifier
}

output "cluster_arn" {
  description = "ARN of the cluster."
  value       = aws_rds_cluster.main.arn
}

output "cluster_resource_id" {
  description = "Resource ID of the cluster (cluster-...), the part of an rds-db:connect resource ARN that names the cluster: arn:{partition}:rds-db:{region}:{account}:dbuser:{cluster_resource_id}/<db user>."
  value       = aws_rds_cluster.main.cluster_resource_id
}

output "cluster_endpoint" {
  description = "Writer endpoint. Follows the writer through failovers; use it for anything that writes."
  value       = aws_rds_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "Reader endpoint. Balances connections across the readers, or reaches the writer when there are none."
  value       = aws_rds_cluster.main.reader_endpoint
}

output "cluster_port" {
  description = "Port the cluster listens on."
  value       = aws_rds_cluster.main.port
}

output "database_name" {
  description = "Name of the database created with the cluster. Null or empty when database_name was null: connect to \"postgres\" then."
  value       = aws_rds_cluster.main.database_name
}

output "master_username" {
  description = "Name of the master database user."
  value       = aws_rds_cluster.main.master_username
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret in which RDS keeps the master user's credentials, or null when manage_master_user_password is false. Grant secretsmanager:GetSecretValue on it only to the people and tools that administer the database."
  value       = one(aws_rds_cluster.main.master_user_secret[*].secret_arn)
}

output "security_group_id" {
  description = "ID of the cluster's security group. Add ingress rules for your clients to it, on cluster_port."
  value       = aws_security_group.aurora.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group."
  value       = aws_db_subnet_group.main.name
}

output "instance_identifiers" {
  description = "Identifiers of the instances, \"{name}-instance-{n}\" for n = 1 to instance_count. Which one is the writer can change at every failover."
  value       = aws_rds_cluster_instance.main[*].identifier
}
