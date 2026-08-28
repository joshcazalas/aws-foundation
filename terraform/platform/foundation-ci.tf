locals {
  foundation_management_plan_role_arn = "arn:aws:iam::${var.management_account_id}:role/AWSFoundationTerraformPlan"
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
