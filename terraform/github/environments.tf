locals {
  repository_name = "money-on-record"

  environments = {
    uat = {
      account_id        = "732006412638"
      deploy_role_name  = "MoneyOnRecordDeployUat"
      state_bucket_name = "money-on-record-uat-732006412638-tfstate"
    }
    production = {
      account_id        = "134604497564"
      deploy_role_name  = "MoneyOnRecordDeployProd"
      state_bucket_name = "money-on-record-prod-134604497564-tfstate"
    }
  }

  environment_variables = merge([
    for environment, config in local.environments : {
      for name, value in {
        AWS_ACCOUNT_ID  = config.account_id
        AWS_REGION      = "us-east-1"
        AWS_ROLE_ARN    = "arn:aws:iam::${config.account_id}:role/${config.deploy_role_name}"
        TF_STATE_BUCKET = config.state_bucket_name
        } : "${environment}:${name}" => {
        environment = environment
        name        = name
        value       = value
      }
    }
  ]...)
}

resource "github_repository_environment" "this" {
  for_each = local.environments

  repository          = local.repository_name
  environment         = each.key
  wait_timer          = 0
  can_admins_bypass   = true
  prevent_self_review = false

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "github_repository_environment_deployment_policy" "main" {
  for_each = local.environments

  repository     = local.repository_name
  environment    = github_repository_environment.this[each.key].environment
  branch_pattern = "main"
}

resource "github_actions_environment_variable" "this" {
  for_each = local.environment_variables

  repository    = local.repository_name
  environment   = github_repository_environment.this[each.value.environment].environment
  variable_name = each.value.name
  value         = each.value.value
}
