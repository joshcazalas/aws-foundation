locals {
  repository_name = "money-on-record"

  account_ids            = data.terraform_remote_state.organization.outputs.account_ids
  deployment_account_id  = local.account_ids["deployment"]
  application_state_name = "joshcazalas-deployment-tfstate-${local.deployment_account_id}"

  environments = {
    uat = {
      account_id               = local.account_ids["workloads-uat"]
      hub_deploy_role_name     = "MoneyOnRecordDeployUat"
      hub_plan_role_name       = "MoneyOnRecordPlanUat"
      workload_deploy_role_arn = "arn:aws:iam::${local.account_ids["workloads-uat"]}:role/MoneyOnRecordTerraformDeploy"
      workload_plan_role_arn   = "arn:aws:iam::${local.account_ids["workloads-uat"]}:role/MoneyOnRecordTerraformPlan"
    }
    production = {
      account_id               = local.account_ids["workloads-prod"]
      hub_deploy_role_name     = "MoneyOnRecordDeployProd"
      hub_plan_role_name       = "MoneyOnRecordPlanProd"
      workload_deploy_role_arn = "arn:aws:iam::${local.account_ids["workloads-prod"]}:role/MoneyOnRecordTerraformDeploy"
      workload_plan_role_arn   = "arn:aws:iam::${local.account_ids["workloads-prod"]}:role/MoneyOnRecordTerraformPlan"
    }
  }

  environment_variables = merge([
    for environment, config in local.environments : {
      for name, value in {
        AWS_ACCOUNT_ID            = config.account_id
        AWS_DEPLOYMENT_ACCOUNT_ID = local.deployment_account_id
        AWS_REGION                = "us-east-1"
        AWS_ROLE_ARN              = "arn:aws:iam::${local.deployment_account_id}:role/${config.hub_deploy_role_name}"
        AWS_WORKLOAD_ROLE_ARN     = config.workload_deploy_role_arn
        TF_STATE_BUCKET           = local.application_state_name
        TF_WORKSPACE              = environment
        } : "${environment}:${name}" => {
        environment = environment
        name        = name
        value       = value
      }
    }
  ]...)

  repository_variables = merge(
    {
      AWS_DEPLOYMENT_ACCOUNT_ID = local.deployment_account_id
      AWS_REGION                = "us-east-1"
      TF_STATE_BUCKET           = local.application_state_name
    },
    merge([
      for environment, config in local.environments : {
        "AWS_PLAN_ROLE_ARN_${upper(environment)}"          = "arn:aws:iam::${local.deployment_account_id}:role/${config.hub_plan_role_name}"
        "AWS_WORKLOAD_PLAN_ROLE_ARN_${upper(environment)}" = config.workload_plan_role_arn
      }
    ]...),
  )
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

resource "github_actions_variable" "this" {
  for_each = local.repository_variables

  repository    = local.repository_name
  variable_name = each.key
  value         = each.value
}
