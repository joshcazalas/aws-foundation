locals {
  github_common_trust_conditions = [
    {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:repository_id"
      values   = [var.github_repository_id]
    },
    {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:repository_owner_id"
      values   = [var.github_repository_owner_id]
    },
    {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:environment"
      values   = [var.github_environment]
    },
  ]

  github_deploy_trust_conditions = concat(
    local.github_common_trust_conditions,
    [
      {
        test     = "StringEquals"
        variable = "token.actions.githubusercontent.com:ref"
        values   = ["refs/heads/main"]
      },
    ],
    var.github_actor_id == null ? [] : [
      {
        test     = "StringEquals"
        variable = "token.actions.githubusercontent.com:actor_id"
        values   = [var.github_actor_id]
      },
    ],
  )

  state_prefixes = [
    "bootstrap/*",
    "etl/*",
    "shared/*",
    "static-site/*",
  ]

  plan_state_permissions = var.enable_state_access ? {
    ListStateBucket = {
      actions   = ["s3:ListBucket"]
      resources = [aws_s3_bucket.state.arn]
      condition = [{
        test     = "StringLike"
        variable = "s3:prefix"
        values   = local.state_prefixes
      }]
    }
    ReadState = {
      actions   = ["s3:GetObject"]
      resources = [for prefix in local.state_prefixes : "${aws_s3_bucket.state.arn}/${trimsuffix(prefix, "*")}terraform.tfstate"]
    }
    ManageStateLocks = {
      actions = [
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:PutObject",
      ]
      resources = [for prefix in local.state_prefixes : "${aws_s3_bucket.state.arn}/${trimsuffix(prefix, "*")}terraform.tfstate.tflock"]
    }
  } : null

  deploy_state_permissions = var.enable_state_access ? {
    ListStateBucket = {
      actions   = ["s3:ListBucket"]
      resources = [aws_s3_bucket.state.arn]
      condition = [{
        test     = "StringLike"
        variable = "s3:prefix"
        values   = local.state_prefixes
      }]
    }
    ReadWriteState = {
      actions = [
        "s3:GetObject",
        "s3:PutObject",
      ]
      resources = [for prefix in local.state_prefixes : "${aws_s3_bucket.state.arn}/${trimsuffix(prefix, "*")}terraform.tfstate"]
    }
    ManageStateLocks = {
      actions = [
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:PutObject",
      ]
      resources = [for prefix in local.state_prefixes : "${aws_s3_bucket.state.arn}/${trimsuffix(prefix, "*")}terraform.tfstate.tflock"]
    }
  } : null
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Component = "github-oidc"
  }

  lifecycle {
    prevent_destroy = true
  }
}

module "plan_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.0"

  name            = var.plan_role_name
  use_name_prefix = false
  description     = "Terraform plan identity for ${var.github_repository_name} ${var.environment}"

  enable_oidc             = true
  oidc_provider_urls      = ["token.actions.githubusercontent.com"]
  oidc_audiences          = ["sts.amazonaws.com"]
  oidc_subjects           = [var.github_subject]
  trust_policy_conditions = local.github_common_trust_conditions

  create_inline_policy      = var.enable_state_access
  inline_policy_permissions = local.plan_state_permissions

  tags = {
    Component = "github-oidc"
  }

  depends_on = [aws_iam_openid_connect_provider.github_actions]
}

module "deploy_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.0"

  name            = var.deploy_role_name
  use_name_prefix = false
  description     = "Terraform deployment identity for ${var.github_repository_name} ${var.environment}"

  enable_oidc             = true
  oidc_provider_urls      = ["token.actions.githubusercontent.com"]
  oidc_audiences          = ["sts.amazonaws.com"]
  oidc_subjects           = [var.github_subject]
  trust_policy_conditions = local.github_deploy_trust_conditions

  create_inline_policy      = var.enable_state_access
  inline_policy_permissions = local.deploy_state_permissions

  tags = {
    Component = "github-oidc"
  }

  depends_on = [aws_iam_openid_connect_provider.github_actions]
}
