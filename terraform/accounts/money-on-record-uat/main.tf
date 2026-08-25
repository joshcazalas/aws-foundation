module "baseline" {
  source = "../../modules/workload-account-baseline"

  account_id        = "732006412638"
  environment       = "uat"
  state_bucket_name = "money-on-record-uat-732006412638-tfstate"

  github_repository_name     = "joshcazalas/money-on-record"
  github_repository_id       = "1338755168"
  github_repository_owner_id = "73436834"
  github_environment         = "uat"
  github_subject             = "repo:joshcazalas@73436834/money-on-record@1338755168:environment:uat"

  plan_role_name   = "MoneyOnRecordPlan"
  deploy_role_name = "MoneyOnRecordDeployUat"

  # Enable only after the identity-only OIDC smoke test succeeds.
  enable_state_access = false
}
