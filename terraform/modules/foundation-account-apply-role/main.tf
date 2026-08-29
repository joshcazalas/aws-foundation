locals {
  read_iam_configuration = {
    ReadIAMConfiguration = {
      actions = [
        "iam:GetOpenIDConnectProvider",
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListOpenIDConnectProviderTags",
        "iam:ListOpenIDConnectProviders",
        "iam:ListRolePolicies",
        "iam:ListRoleTags",
      ]
      resources = ["*"]
    }
  }

  manage_roles = {
    ManageReviewedIAMRoles = {
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
      resources = var.managed_role_arns
    }
  }

  manage_oidc_providers = length(var.managed_oidc_provider_arns) == 0 ? {} : {
    ManageReviewedOIDCProviders = {
      actions = [
        "iam:AddClientIDToOpenIDConnectProvider",
        "iam:CreateOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:RemoveClientIDFromOpenIDConnectProvider",
        "iam:TagOpenIDConnectProvider",
        "iam:UntagOpenIDConnectProvider",
        "iam:UpdateOpenIDConnectProviderThumbprint",
      ]
      resources = var.managed_oidc_provider_arns
    }
  }

  manage_buckets = length(var.managed_bucket_arns) == 0 ? {} : {
    ReadReviewedBucketConfiguration = {
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
        "s3:ListTagsForResource",
      ]
      resources = var.managed_bucket_arns
    }
    ManageReviewedBucketConfiguration = {
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
      resources = var.managed_bucket_arns
    }
  }

  account_public_access = {
    ManageAccountPublicAccess = {
      actions = [
        "s3:GetAccountPublicAccessBlock",
        "s3:PutAccountPublicAccessBlock",
      ]
      resources = ["*"]
    }
  }
}

module "this" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.0"

  name                 = var.role_name
  use_name_prefix      = false
  description          = "Member-account execution role for reviewed aws-foundation platform applies"
  max_session_duration = 3600

  trust_policy_permissions = {
    AllowManagementFoundationPlatformApply = {
      actions = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]

      principals = [{
        type        = "AWS"
        identifiers = [var.management_apply_role_arn]
      }]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = merge(
    local.read_iam_configuration,
    local.manage_roles,
    local.manage_oidc_providers,
    local.manage_buckets,
    local.account_public_access,
  )

  tags = {
    Application = "aws-foundation"
    Component   = "terraform-apply"
  }
}
