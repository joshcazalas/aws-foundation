locals {
  foundation_management_plan_role_arn  = "arn:aws:iam::${var.management_account_id}:role/AWSFoundationTerraformPlan"
  foundation_management_apply_role_arn = "arn:aws:iam::${var.management_account_id}:role/AWSFoundationPlatformApply"
}

module "foundation_plan_deployment" {
  providers = {
    aws = aws.deployment
  }

  source = "../modules/foundation-account-plan-role"

  management_plan_role_arn = local.foundation_management_plan_role_arn

  additional_read_permissions = {
    ReadApplicationStateBucketConfiguration = {
      actions = [
        "s3:GetAccelerateConfiguration",
        "s3:GetBucketAcl",
        "s3:GetBucketCORS",
        "s3:GetBucketLocation",
        "s3:GetBucketLogging",
        "s3:GetBucketObjectLockConfiguration",
        "s3:GetBucketOwnershipControls",
        "s3:GetBucketPolicy",
        "s3:GetBucketPolicyStatus",
        "s3:GetBucketPublicAccessBlock",
        "s3:GetBucketRequestPayment",
        "s3:GetBucketTagging",
        "s3:GetBucketVersioning",
        "s3:GetBucketWebsite",
        "s3:GetEncryptionConfiguration",
        "s3:GetLifecycleConfiguration",
        "s3:GetReplicationConfiguration",
        "s3:ListBucket",
      ]
      resources = [aws_s3_bucket.application_state.arn]
    }
  }
}

module "foundation_plan_uat" {
  providers = {
    aws = aws.workloads_uat
  }

  source = "../modules/foundation-account-plan-role"

  management_plan_role_arn = local.foundation_management_plan_role_arn
}

module "foundation_plan_production" {
  providers = {
    aws = aws.workloads_production
  }

  source = "../modules/foundation-account-plan-role"

  management_plan_role_arn = local.foundation_management_plan_role_arn
}

module "foundation_apply_deployment" {
  providers = {
    aws = aws.deployment
  }

  source = "../modules/foundation-account-apply-role"

  account_id                = local.account_ids["deployment"]
  management_apply_role_arn = local.foundation_management_apply_role_arn
  managed_bucket_arns       = [aws_s3_bucket.application_state.arn]
  managed_oidc_provider_arns = [
    "arn:aws:iam::${local.account_ids["deployment"]}:oidc-provider/token.actions.githubusercontent.com",
  ]
  managed_role_arns = [
    "arn:aws:iam::${local.account_ids["deployment"]}:role/AWSFoundationTerraformApply",
    "arn:aws:iam::${local.account_ids["deployment"]}:role/AWSFoundationTerraformPlan",
    "arn:aws:iam::${local.account_ids["deployment"]}:role/MoneyOnRecordDeployProd",
    "arn:aws:iam::${local.account_ids["deployment"]}:role/MoneyOnRecordDeployUat",
    "arn:aws:iam::${local.account_ids["deployment"]}:role/MoneyOnRecordPlanProd",
    "arn:aws:iam::${local.account_ids["deployment"]}:role/MoneyOnRecordPlanUat",
  ]
}

module "foundation_apply_uat" {
  providers = {
    aws = aws.workloads_uat
  }

  source = "../modules/foundation-account-apply-role"

  account_id                = local.account_ids["workloads-uat"]
  management_apply_role_arn = local.foundation_management_apply_role_arn
  managed_role_arns = [
    "arn:aws:iam::${local.account_ids["workloads-uat"]}:role/AWSFoundationTerraformApply",
    "arn:aws:iam::${local.account_ids["workloads-uat"]}:role/AWSFoundationTerraformPlan",
    "arn:aws:iam::${local.account_ids["workloads-uat"]}:role/MoneyOnRecordTerraformDeploy",
    "arn:aws:iam::${local.account_ids["workloads-uat"]}:role/MoneyOnRecordTerraformPlan",
  ]
}

module "foundation_apply_production" {
  providers = {
    aws = aws.workloads_production
  }

  source = "../modules/foundation-account-apply-role"

  account_id                = local.account_ids["workloads-prod"]
  management_apply_role_arn = local.foundation_management_apply_role_arn
  managed_role_arns = [
    "arn:aws:iam::${local.account_ids["workloads-prod"]}:role/AWSFoundationTerraformApply",
    "arn:aws:iam::${local.account_ids["workloads-prod"]}:role/AWSFoundationTerraformPlan",
    "arn:aws:iam::${local.account_ids["workloads-prod"]}:role/MoneyOnRecordTerraformDeploy",
    "arn:aws:iam::${local.account_ids["workloads-prod"]}:role/MoneyOnRecordTerraformPlan",
  ]
}
