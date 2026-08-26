output "deploy_role_arn" {
  description = "Workload-account Terraform deployment role ARN."
  value       = module.deploy_role.arn
}

output "plan_role_arn" {
  description = "Workload-account Terraform plan role ARN."
  value       = module.plan_role.arn
}
