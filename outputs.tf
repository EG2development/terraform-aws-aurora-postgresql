# Every output has a description. Output what callers need to wire other
# resources to this module's: names, ARNs, IDs, URLs.

output "name" {
  description = "Name of the managed resource."
  value       = var.name
}

output "tags" {
  description = "Tags applied to every resource, including the generated Name tag."
  value       = local.tags
}

output "account_id" {
  description = "AWS account the module was planned in. Placeholder: remove with the data source in main.tf."
  value       = data.aws_caller_identity.current.account_id
}
