output "deploy_role_arn" {
  description = "GitHub OIDC deployment role ARN."
  value       = module.deploy_role.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "plan_role_arn" {
  description = "GitHub OIDC plan role ARN."
  value       = module.plan_role.arn
}

output "state_bucket_arn" {
  description = "Terraform state bucket ARN."
  value       = aws_s3_bucket.state.arn
}

output "state_bucket_name" {
  description = "Terraform state bucket name."
  value       = aws_s3_bucket.state.id
}
