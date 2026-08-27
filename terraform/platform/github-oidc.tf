locals {
  github_repository = {
    actor_id     = "73436834"
    id           = "1338755168"
    name         = "joshcazalas/money-on-record"
    owner_id     = "73436834"
    subject_base = "repo:joshcazalas@73436834/money-on-record@1338755168"
  }

  money_on_record_environments = {
    production = {
      account_id              = local.account_ids["workloads-prod"]
      actor_id                = local.github_repository.actor_id
      deploy_role_name        = "MoneyOnRecordDeployProd"
      github_environment      = "production"
      plan_role_name          = "MoneyOnRecordPlanProd"
      workload_workspace_name = "production"
    }
    uat = {
      account_id              = local.account_ids["workloads-uat"]
      actor_id                = null
      deploy_role_name        = "MoneyOnRecordDeployUat"
      github_environment      = "uat"
      plan_role_name          = "MoneyOnRecordPlanUat"
      workload_workspace_name = "uat"
    }
  }

  money_on_record_state_components = [
    "etl",
    "shared",
    "static-site",
  ]
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  provider = aws.deployment

  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Component = "github-oidc"
  }

  lifecycle {
    prevent_destroy = true

    precondition {
      condition = (
        !anytrue(values(var.enable_money_on_record_state_access)) || (
          var.money_on_record_plan_job_workflow_ref != null &&
          var.money_on_record_deploy_job_workflow_ref != null
        )
      )
      error_message = "Set exact plan and deploy job_workflow_ref values before enabling any Money on Record state access."
    }
  }
}

module "money_on_record_hub_roles" {
  for_each = local.money_on_record_environments

  providers = {
    aws = aws.deployment
  }

  source = "../modules/github-environment-roles"

  application_name = "money-on-record"
  environment      = each.key

  github_repository_name         = local.github_repository.name
  github_repository_id           = local.github_repository.id
  github_repository_owner_id     = local.github_repository.owner_id
  github_environment             = each.value.github_environment
  github_actor_id                = each.value.actor_id
  github_deploy_subject          = "${local.github_repository.subject_base}:environment:${each.value.github_environment}"
  github_plan_subject            = "${local.github_repository.subject_base}:pull_request"
  github_deploy_job_workflow_ref = var.money_on_record_deploy_job_workflow_ref
  github_plan_job_workflow_ref   = var.money_on_record_plan_job_workflow_ref

  deploy_role_name = each.value.deploy_role_name
  plan_role_name   = each.value.plan_role_name

  workload_deploy_role_arn = "arn:aws:iam::${each.value.account_id}:role/MoneyOnRecordTerraformDeploy"
  workload_plan_role_arn   = "arn:aws:iam::${each.value.account_id}:role/MoneyOnRecordTerraformPlan"

  state_bucket_arn = aws_s3_bucket.application_state.arn
  state_object_keys = [
    for component in local.money_on_record_state_components :
    "money-on-record/${component}/${each.value.workload_workspace_name}/terraform.tfstate"
  ]

  enable_state_access = var.enable_money_on_record_state_access[each.key]

  depends_on = [aws_iam_openid_connect_provider.github_actions]
}
