locals {
  # These APIs expose Terraform-managed control-plane configuration. They do
  # not grant access to application data, state objects, credentials, or
  # secrets.
  base_read_permissions = {
    ReadIAMConfiguration = {
      actions = [
        "iam:GetOpenIDConnectProvider",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListOpenIDConnectProviderTags",
        "iam:ListOpenIDConnectProviders",
        "iam:ListPolicies",
        "iam:ListPolicyTags",
        "iam:ListPolicyVersions",
        "iam:ListRolePolicies",
        "iam:ListRoleTags",
      ]
      resources = ["*"]
    }
    ReadAccountPublicAccess = {
      actions   = ["s3:GetAccountPublicAccessBlock"]
      resources = ["*"]
    }
  }
}

module "this" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.0"

  name                 = var.role_name
  use_name_prefix      = false
  description          = "Read-only member-account execution role for aws-foundation pull-request plans"
  max_session_duration = 3600

  trust_policy_permissions = {
    AllowManagementFoundationPlan = {
      actions = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]

      principals = [{
        type        = "AWS"
        identifiers = [var.management_plan_role_arn]
      }]
    }
  }

  create_inline_policy      = true
  inline_policy_permissions = merge(local.base_read_permissions, var.additional_read_permissions)

  tags = {
    Application = "aws-foundation"
    Component   = "terraform-plan"
  }
}
