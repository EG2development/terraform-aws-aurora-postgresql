output "cluster_endpoint" {
  description = "Writer endpoint, for the application's read-write connections."
  value       = module.aurora.cluster_endpoint
}

output "cluster_reader_endpoint" {
  description = "Reader endpoint, for read-only connections."
  value       = module.aurora.cluster_reader_endpoint
}

output "master_user_secret_arn" {
  description = "Secrets Manager secret that holds the master user's credentials."
  value       = module.aurora.master_user_secret_arn
}

output "connect_policy_arn" {
  description = "IAM policy to attach to the application's role."
  value       = aws_iam_policy.connect.arn
}
