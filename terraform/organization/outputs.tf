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

output "deployments_ou_id" {
  description = "Deployments organizational unit ID."
  value       = aws_organizations_organizational_unit.deployments.id
}

output "nonproduction_ou_id" {
  description = "NonProduction organizational unit ID."
  value       = aws_organizations_organizational_unit.nonproduction.id
}

output "production_ou_id" {
  description = "Production organizational unit ID."
  value       = aws_organizations_organizational_unit.production.id
}

output "account_ids" {
  description = "Foundation account IDs keyed by deployment, workloads-uat, and workloads-prod."
  value       = { for key, account in aws_organizations_account.foundation : key => account.id }
}

output "foundation_plan_role_arn" {
  description = "Management-account GitHub OIDC role used for read-only foundation pull-request plans."
  value       = module.foundation_plan_role.arn
}
