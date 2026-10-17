output "cluster_endpoint" {
  description = "Writer endpoint."
  value       = module.aurora.cluster_endpoint
}

output "master_user_secret_arn" {
  description = "Secrets Manager secret that holds the master user's credentials."
  value       = module.aurora.master_user_secret_arn
}

output "security_group_id" {
  description = "Security group to add client rules to."
  value       = module.aurora.security_group_id
}
