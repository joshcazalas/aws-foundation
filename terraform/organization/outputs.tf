output "budget_alerts_topic_arn" {
  description = "SNS topic to subscribe to out of band for budget alerts."
  value       = aws_sns_topic.budget_alerts.arn
}

output "organization_id" {
  description = "Managed AWS Organization ID."
  value       = aws_organizations_organization.foundation.id
}

output "workloads_ou_id" {
  description = "Workloads organizational unit ID."
  value       = aws_organizations_organizational_unit.workloads.id
}

output "workload_account_ids" {
  description = "Account IDs keyed by environment."
  value       = { for key, account in aws_organizations_account.workload : key => account.id }
}
