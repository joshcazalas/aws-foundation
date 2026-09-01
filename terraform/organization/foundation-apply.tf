locals {
  foundation_apply_caller_workflow_name = "Apply merged foundation configuration"

  foundation_apply_trust_conditions = [
    {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:actor_id"
      values   = [local.foundation_ci_repository.owner_id]
    },
    {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:ref"
      values   = ["refs/heads/main"]
    },
    {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:repository_id"
      values   = [local.foundation_ci_repository.id]
    },
    {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:repository_owner_id"
      values   = [local.foundation_ci_repository.owner_id]
    },
    {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:workflow"
      values   = [local.foundation_apply_caller_workflow_name]
    },
  ]

  foundation_apply_role_names = {
    management_state = "AWSFoundationManagementStateApply"
    organization     = "AWSFoundationOrganizationApply"
    platform         = "AWSFoundationPlatformApply"
  }

  foundation_apply_role_arns = {
    for root, name in local.foundation_apply_role_names :
    root => "arn:aws:iam::${var.management_account_id}:role/${name}"
  }

  foundation_apply_state = {
    management_state = {
      key            = "aws-foundation/management-state/terraform.tfstate"
      read_only_keys = []
      list_prefixes  = ["aws-foundation/management-state/*"]
    }
    organization = {
      key            = "aws-foundation/organization/terraform.tfstate"
      read_only_keys = []
      list_prefixes  = ["aws-foundation/organization/*"]
    }
    platform = {
      key            = "aws-foundation/platform/terraform.tfstate"
      read_only_keys = ["aws-foundation/organization/terraform.tfstate"]
      list_prefixes = [
        "aws-foundation/organization/*",
        "aws-foundation/platform/*",
      ]
    }
  }

  foundation_apply_state_permissions = {
    for root, config in local.foundation_apply_state : root => merge(
      {
        ListRootState = {
          actions   = ["s3:ListBucket"]
          resources = [local.foundation_state_bucket_arn]
          condition = [{
            test     = "StringLike"
            variable = "s3:prefix"
            values   = config.list_prefixes
          }]
        }
        ReadWriteRootState = {
          actions = [
            "s3:GetObject",
            "s3:PutObject",
          ]
          resources = ["${local.foundation_state_bucket_arn}/${config.key}"]
        }
        ManageRootStateLock = {
          actions = [
            "s3:DeleteObject",
            "s3:GetObject",
            "s3:PutObject",
          ]
          resources = ["${local.foundation_state_bucket_arn}/${config.key}.tflock"]
        }
      },
      length(config.read_only_keys) == 0 ? {} : {
        ReadDependencyState = {
          actions = ["s3:GetObject"]
          resources = [
            for key in config.read_only_keys : "${local.foundation_state_bucket_arn}/${key}"
          ]
        }
      },
    )
  }

  foundation_management_state_permissions = {
    ManageFoundationStateBucket = {
      actions = [
        "s3:CreateBucket",
        "s3:DeleteBucketPolicy",
        "s3:DeleteBucketWebsite",
        "s3:PutBucketOwnershipControls",
        "s3:PutBucketPolicy",
        "s3:PutBucketPublicAccessBlock",
        "s3:PutBucketTagging",
        "s3:PutBucketVersioning",
        "s3:PutEncryptionConfiguration",
        "s3:TagResource",
        "s3:UntagResource",
      ]
      resources = [local.foundation_state_bucket_arn]
    }
    ManageManagementAccountPublicAccess = {
      actions = [
        "s3:GetAccountPublicAccessBlock",
        "s3:PutAccountPublicAccessBlock",
      ]
      resources = ["*"]
    }
  }

  foundation_organization_permissions = {
    ManageOrganizationStructure = {
      actions = [
        "account:PutAccountName",
        "organizations:AttachPolicy",
        "organizations:CreateAccount",
        "organizations:CreateOrganizationalUnit",
        "organizations:CreatePolicy",
        "organizations:DeleteOrganizationalUnit",
        "organizations:DeletePolicy",
        "organizations:DescribeCreateAccountStatus",
        "organizations:DetachPolicy",
        "organizations:DisableAWSServiceAccess",
        "organizations:DisablePolicyType",
        "organizations:EnableAWSServiceAccess",
        "organizations:EnablePolicyType",
        "organizations:MoveAccount",
        "organizations:TagResource",
        "organizations:UntagResource",
        "organizations:UpdateOrganizationalUnit",
        "organizations:UpdatePolicy",
      ]
      resources = ["*"]
    }
    ManageCentralizedRootAccess = {
      actions = [
        "iam:DisableOrganizationsRootCredentialsManagement",
        "iam:DisableOrganizationsRootSessions",
        "iam:EnableOrganizationsRootCredentialsManagement",
        "iam:EnableOrganizationsRootSessions",
        "iam:ListOrganizationsFeatures",
      ]
      resources = ["*"]
    }
    ManageIdentityCenter = {
      actions = [
        "sso:AttachManagedPolicyToPermissionSet",
        "sso:CreateAccountAssignment",
        "sso:CreatePermissionSet",
        "sso:DeleteAccountAssignment",
        "sso:DeletePermissionSet",
        "sso:DescribeAccountAssignmentCreationStatus",
        "sso:DescribeAccountAssignmentDeletionStatus",
        "sso:DescribePermissionSet",
        "sso:DescribePermissionSetProvisioningStatus",
        "sso:DetachManagedPolicyFromPermissionSet",
        "sso:ListAccountAssignments",
        "sso:ListManagedPoliciesInPermissionSet",
        "sso:ListTagsForResource",
        "sso:ProvisionPermissionSet",
        "sso:TagResource",
        "sso:UntagResource",
        "sso:UpdatePermissionSet",
      ]
      resources = ["*"]
    }
    ManageBudgets = {
      actions = [
        "budgets:ListTagsForResource",
        "budgets:ModifyBudget",
        "budgets:TagResource",
        "budgets:UntagResource",
        "budgets:ViewBudget",
      ]
      resources = ["arn:aws:budgets::${var.management_account_id}:budget/*"]
    }
    ModifyBillingForBudgets = {
      actions   = ["aws-portal:ModifyBilling"]
      resources = ["*"]
    }
    ManageBudgetAlertsTopic = {
      actions = [
        "sns:CreateTopic",
        "sns:DeleteTopic",
        "sns:GetTopicAttributes",
        "sns:ListTagsForResource",
        "sns:SetTopicAttributes",
        "sns:TagResource",
        "sns:UntagResource",
      ]
      resources = ["arn:aws:sns:${var.aws_region}:${var.management_account_id}:aws-foundation-budget-alerts"]
    }
    ReadManagementAccountConfiguration = local.foundation_plan_permissions.ReadManagementAccountConfiguration
  }

  foundation_automation_role_arns = concat(
    ["arn:aws:iam::${var.management_account_id}:role/AWSFoundationTerraformPlan"],
    values(local.foundation_apply_role_arns),
  )

  foundation_automation_iam_permissions = {
    ManageFoundationAutomationRoles = {
      actions = [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:DeleteRolePolicy",
        "iam:PutRolePolicy",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:UpdateRole",
        "iam:UpdateRoleDescription",
      ]
      resources = local.foundation_automation_role_arns
    }
    ManageFoundationOIDCProvider = {
      actions = [
        "iam:AddClientIDToOpenIDConnectProvider",
        "iam:CreateOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:RemoveClientIDFromOpenIDConnectProvider",
        "iam:TagOpenIDConnectProvider",
        "iam:UntagOpenIDConnectProvider",
        "iam:UpdateOpenIDConnectProviderThumbprint",
      ]
      resources = ["arn:aws:iam::${var.management_account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }
  }

  foundation_platform_permissions = {
    AssumeMemberApplyRoles = {
      actions = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]
      resources = [
        for account in aws_organizations_account.foundation :
        "arn:aws:iam::${account.id}:role/AWSFoundationTerraformApply"
      ]
    }
  }
}

module "foundation_management_state_apply_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.0"

  name                 = local.foundation_apply_role_names.management_state
  use_name_prefix      = false
  description          = "Main-only GitHub Actions role for reviewed management-state applies"
  max_session_duration = 3600

  enable_oidc             = true
  oidc_provider_urls      = ["token.actions.githubusercontent.com"]
  oidc_audiences          = ["sts.amazonaws.com"]
  oidc_subjects           = ["${local.foundation_ci_repository.subject_base}:ref:refs/heads/main"]
  trust_policy_conditions = local.foundation_apply_trust_conditions

  create_inline_policy = true
  inline_policy_permissions = merge(
    local.foundation_apply_state_permissions.management_state,
    {
      ReadFoundationStateBucketConfiguration = local.foundation_plan_permissions.ReadFoundationStateBucketConfiguration
    },
    local.foundation_management_state_permissions,
  )

  tags = {
    Application = "aws-foundation"
    Component   = "terraform-apply"
    Root        = "management-state"
  }

  depends_on = [aws_iam_openid_connect_provider.foundation_github_actions]
}

module "foundation_organization_apply_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.0"

  name                 = local.foundation_apply_role_names.organization
  use_name_prefix      = false
  description          = "Main-only GitHub Actions role for reviewed organization applies"
  max_session_duration = 3600

  enable_oidc             = true
  oidc_provider_urls      = ["token.actions.githubusercontent.com"]
  oidc_audiences          = ["sts.amazonaws.com"]
  oidc_subjects           = ["${local.foundation_ci_repository.subject_base}:ref:refs/heads/main"]
  trust_policy_conditions = local.foundation_apply_trust_conditions

  create_inline_policy = true
  inline_policy_permissions = merge(
    local.foundation_apply_state_permissions.organization,
    local.foundation_organization_permissions,
    local.foundation_automation_iam_permissions,
  )

  tags = {
    Application = "aws-foundation"
    Component   = "terraform-apply"
    Root        = "organization"
  }

  depends_on = [aws_iam_openid_connect_provider.foundation_github_actions]
}

module "foundation_platform_apply_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.0"

  name                 = local.foundation_apply_role_names.platform
  use_name_prefix      = false
  description          = "Main-only GitHub Actions hub for reviewed platform applies"
  max_session_duration = 3600

  enable_oidc             = true
  oidc_provider_urls      = ["token.actions.githubusercontent.com"]
  oidc_audiences          = ["sts.amazonaws.com"]
  oidc_subjects           = ["${local.foundation_ci_repository.subject_base}:ref:refs/heads/main"]
  trust_policy_conditions = local.foundation_apply_trust_conditions

  create_inline_policy = true
  inline_policy_permissions = merge(
    local.foundation_apply_state_permissions.platform,
    local.foundation_platform_permissions,
  )

  tags = {
    Application = "aws-foundation"
    Component   = "terraform-apply"
    Root        = "platform"
  }

  depends_on = [aws_iam_openid_connect_provider.foundation_github_actions]
}
