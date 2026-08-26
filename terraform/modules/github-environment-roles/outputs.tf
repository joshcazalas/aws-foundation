output "deploy_role_arn" {
  description = "GitHub OIDC deployment hub role ARN."
  value       = module.deploy_role.arn
}

output "plan_role_arn" {
  description = "GitHub OIDC plan hub role ARN."
  value       = module.plan_role.arn
}
