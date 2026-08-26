module "account_public_access" {
  source  = "terraform-aws-modules/s3-bucket/aws//modules/account-public-access"
  version = "5.15.4"

  account_id = var.account_id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "plan_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.0"

  name                 = var.plan_role_name
  use_name_prefix      = false
  description          = "Terraform plan execution role for ${var.application_name} in ${var.environment}"
  max_session_duration = 3600

  trust_policy_permissions = {
    AllowDeploymentHub = {
      actions = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]

      principals = [{
        type        = "AWS"
        identifiers = [var.hub_plan_role_arn]
      }]
    }
  }

  tags = {
    Application = var.application_name
    Component   = "terraform-execution"
    Environment = var.environment
  }
}

module "deploy_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.0"

  name                 = var.deploy_role_name
  use_name_prefix      = false
  description          = "Terraform deployment execution role for ${var.application_name} in ${var.environment}"
  max_session_duration = 3600

  trust_policy_permissions = {
    AllowDeploymentHub = {
      actions = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]

      principals = [{
        type        = "AWS"
        identifiers = [var.hub_deploy_role_arn]
      }]
    }
  }

  tags = {
    Application = var.application_name
    Component   = "terraform-execution"
    Environment = var.environment
  }
}
