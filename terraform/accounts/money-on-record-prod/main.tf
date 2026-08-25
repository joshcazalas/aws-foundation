module "baseline" {
  source = "../../modules/workload-account-baseline"

  account_id        = "134604497564"
  environment       = "production"
  state_bucket_name = "money-on-record-prod-134604497564-tfstate"

  github_repository_name     = "joshcazalas/money-on-record"
  github_repository_id       = "1338755168"
  github_repository_owner_id = "73436834"
  github_environment         = "production"
  github_subject             = "repo:joshcazalas@73436834/money-on-record@1338755168:environment:production"
  github_actor_id            = "73436834"

  plan_role_name   = "MoneyOnRecordPlan"
  deploy_role_name = "MoneyOnRecordDeployProd"

  # Enable only after the identity-only OIDC smoke test succeeds.
  enable_state_access = false
}
