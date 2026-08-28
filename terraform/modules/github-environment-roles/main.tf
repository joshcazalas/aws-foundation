locals {
  github_repository_trust_conditions = [
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
  ]

  github_plan_trust_conditions = concat(
    local.github_repository_trust_conditions,
    var.github_plan_job_workflow_ref == null ? [] : [
      {
        test     = "StringEquals"
        variable = "token.actions.githubusercontent.com:job_workflow_ref"
        values   = [var.github_plan_job_workflow_ref]
      },
    ],
  )

  github_deploy_trust_conditions = concat(
    local.github_repository_trust_conditions,
    [
      {
        test     = "StringEquals"
        variable = "token.actions.githubusercontent.com:environment"
        values   = [var.github_environment]
      },
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
    var.github_deploy_job_workflow_ref == null ? [] : [
      {
        test     = "StringEquals"
        variable = "token.actions.githubusercontent.com:job_workflow_ref"
        values   = [var.github_deploy_job_workflow_ref]
      },
    ],
  )

  state_object_arns = [
    for key in var.state_object_keys : "${var.state_bucket_arn}/${key}"
  ]

  state_lock_arns = [
    for key in var.state_object_keys : "${var.state_bucket_arn}/${key}.tflock"
  ]

  state_list_prefixes = [
    # The S3 backend lists the workspace_key_prefix itself to enumerate named
    # workspaces. This exposes object names, never another workspace's contents.
    for key in var.state_object_keys : replace(key, "/${var.environment}/terraform.tfstate", "/*")
  ]

  plan_permissions = merge(
    {
      AssumeWorkloadPlanRole = {
        actions = [
          "sts:AssumeRole",
          "sts:TagSession",
        ]
        resources = [var.workload_plan_role_arn]
      }
    },
    { for key, permission in {
      ListStateBucket = {
        actions   = ["s3:ListBucket"]
        resources = [var.state_bucket_arn]
        condition = [{
          test     = "StringLike"
          variable = "s3:prefix"
          values   = local.state_list_prefixes
        }]
      }
      ReadState = {
        actions = ["s3:GetObject"]
        resources = concat(
          local.state_object_arns,
          local.state_lock_arns,
        )
      }
    } : key => permission if var.enable_state_access },
  )

  deploy_permissions = merge(
    {
      AssumeWorkloadDeployRole = {
        actions = [
          "sts:AssumeRole",
          "sts:TagSession",
        ]
        resources = [var.workload_deploy_role_arn]
      }
    },
    { for key, permission in {
      ListStateBucket = {
        actions   = ["s3:ListBucket"]
        resources = [var.state_bucket_arn]
        condition = [{
          test     = "StringLike"
          variable = "s3:prefix"
          values   = local.state_list_prefixes
        }]
      }
      ReadWriteState = {
        actions = [
          "s3:GetObject",
          "s3:PutObject",
        ]
        resources = local.state_object_arns
      }
      ManageStateLocks = {
        actions = [
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:PutObject",
        ]
        resources = local.state_lock_arns
      }
    } : key => permission if var.enable_state_access },
  )
}

module "plan_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.0"

  name                 = var.plan_role_name
  use_name_prefix      = false
  description          = "GitHub Terraform plan hub for ${var.github_repository_name} ${var.environment}"
  max_session_duration = 3600

  enable_oidc             = true
  oidc_provider_urls      = ["token.actions.githubusercontent.com"]
  oidc_audiences          = ["sts.amazonaws.com"]
  oidc_subjects           = [var.github_plan_subject]
  trust_policy_conditions = local.github_plan_trust_conditions

  create_inline_policy      = true
  inline_policy_permissions = local.plan_permissions

  tags = {
    Application = var.application_name
    Component   = "github-oidc"
    Environment = var.environment
  }
}

module "deploy_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.0"

  name                 = var.deploy_role_name
  use_name_prefix      = false
  description          = "GitHub Terraform deployment hub for ${var.github_repository_name} ${var.environment}"
  max_session_duration = 3600

  enable_oidc             = true
  oidc_provider_urls      = ["token.actions.githubusercontent.com"]
  oidc_audiences          = ["sts.amazonaws.com"]
  oidc_subjects           = [var.github_deploy_subject]
  trust_policy_conditions = local.github_deploy_trust_conditions

  create_inline_policy      = true
  inline_policy_permissions = local.deploy_permissions

  tags = {
    Application = var.application_name
    Component   = "github-oidc"
    Environment = var.environment
  }
}
