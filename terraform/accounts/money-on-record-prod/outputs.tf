output "baseline" {
  description = "Non-secret production account baseline identifiers."
  value = {
    deploy_role_arn          = module.baseline.deploy_role_arn
    github_oidc_provider_arn = module.baseline.github_oidc_provider_arn
    plan_role_arn            = module.baseline.plan_role_arn
    state_bucket_name        = module.baseline.state_bucket_name
  }
}
