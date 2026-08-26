module "workloads_uat" {
  providers = {
    aws = aws.workloads_uat
  }

  source = "../modules/workload-execution-baseline"

  account_id       = local.account_ids["workloads-uat"]
  application_name = "money-on-record"
  environment      = "uat"

  hub_plan_role_arn   = "arn:aws:iam::${local.account_ids["deployment"]}:role/MoneyOnRecordPlanUat"
  hub_deploy_role_arn = "arn:aws:iam::${local.account_ids["deployment"]}:role/MoneyOnRecordDeployUat"

  plan_role_name   = "MoneyOnRecordTerraformPlan"
  deploy_role_name = "MoneyOnRecordTerraformDeploy"

  depends_on = [module.money_on_record_hub_roles["uat"]]
}

module "workloads_production" {
  providers = {
    aws = aws.workloads_production
  }

  source = "../modules/workload-execution-baseline"

  account_id       = local.account_ids["workloads-prod"]
  application_name = "money-on-record"
  environment      = "production"

  hub_plan_role_arn   = "arn:aws:iam::${local.account_ids["deployment"]}:role/MoneyOnRecordPlanProd"
  hub_deploy_role_arn = "arn:aws:iam::${local.account_ids["deployment"]}:role/MoneyOnRecordDeployProd"

  plan_role_name   = "MoneyOnRecordTerraformPlan"
  deploy_role_name = "MoneyOnRecordTerraformDeploy"

  depends_on = [module.money_on_record_hub_roles["production"]]
}
