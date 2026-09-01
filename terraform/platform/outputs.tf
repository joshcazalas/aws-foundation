output "application_state_bucket_name" {
  description = "Centralized application Terraform state bucket in the deployment account."
  value       = aws_s3_bucket.application_state.id
}

output "github_oidc_provider_arn" {
  description = "Centralized GitHub Actions OIDC provider ARN."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "money_on_record_roles" {
  description = "Money on Record hub and workload execution role ARNs by environment."
  value = {
    production = {
      hub_deploy_role_arn      = module.money_on_record_hub_roles["production"].deploy_role_arn
      hub_plan_role_arn        = module.money_on_record_hub_roles["production"].plan_role_arn
      workload_deploy_role_arn = module.workloads_production.deploy_role_arn
      workload_plan_role_arn   = module.workloads_production.plan_role_arn
    }
    uat = {
      hub_artifact_publish_role_arn      = module.money_on_record_uat_artifact_publish_hub_role.arn
      hub_deploy_role_arn                = module.money_on_record_hub_roles["uat"].deploy_role_arn
      hub_plan_role_arn                  = module.money_on_record_hub_roles["uat"].plan_role_arn
      workload_artifact_publish_role_arn = module.money_on_record_uat_artifact_publish_workload_role.arn
      workload_deploy_role_arn           = module.workloads_uat.deploy_role_arn
      workload_plan_role_arn             = module.workloads_uat.plan_role_arn
    }
  }
}

output "foundation_member_plan_role_arns" {
  description = "Read-only foundation plan role ARNs in each member account."
  value = {
    deployment = module.foundation_plan_deployment.role_arn
    production = module.foundation_plan_production.role_arn
    uat        = module.foundation_plan_uat.role_arn
  }
}

output "foundation_member_apply_role_arns" {
  description = "Foundation platform apply role ARNs in each member account."
  value = {
    deployment = module.foundation_apply_deployment.role_arn
    production = module.foundation_apply_production.role_arn
    uat        = module.foundation_apply_uat.role_arn
  }
}
