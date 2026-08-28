locals {
  foundation_ci_repository = {
    id           = "1346584597"
    name         = "joshcazalas/aws-foundation"
    owner_id     = "73436834"
    subject_base = "repo:joshcazalas@73436834/aws-foundation@1346584597"
  }

  foundation_state_bucket_arn = "arn:aws:s3:::joshcazalas-aws-foundation-tfstate-${var.management_account_id}"
  foundation_state_keys = [
    "aws-foundation/github/terraform.tfstate",
    "aws-foundation/management-state/terraform.tfstate",
    "aws-foundation/organization/terraform.tfstate",
    "aws-foundation/platform/terraform.tfstate",
  ]

  foundation_member_plan_role_arns = [
    for account in aws_organizations_account.foundation :
    "arn:aws:iam::${account.id}:role/AWSFoundationTerraformPlan"
  ]

  foundation_plan_trust_conditions = [
    {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:job_workflow_ref"
      values   = [var.foundation_plan_job_workflow_ref]
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
  ]

  foundation_plan_permissions = {
    AssumeMemberPlanRoles = {
      actions = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]
      resources = local.foundation_member_plan_role_arns
    }
    ListFoundationState = {
      actions   = ["s3:ListBucket"]
      resources = [local.foundation_state_bucket_arn]
      condition = [{
        test     = "StringLike"
        variable = "s3:prefix"
        values   = ["aws-foundation/*"]
      }]
    }
    ReadFoundationState = {
      actions = ["s3:GetObject"]
      resources = flatten([
        for key in local.foundation_state_keys : [
          "${local.foundation_state_bucket_arn}/${key}",
          "${local.foundation_state_bucket_arn}/${key}.tflock",
        ]
      ])
    }
    ReadFoundationStateBucketConfiguration = {
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
      resources = [local.foundation_state_bucket_arn]
    }
    ReadManagementAccountConfiguration = {
      actions = [
        "account:GetAccountInformation",
        "budgets:ViewBudget",
        "iam:GetOpenIDConnectProvider",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListOpenIDConnectProviderTags",
        "iam:ListOpenIDConnectProviders",
        "iam:ListOrganizationsFeatures",
        "iam:ListPolicies",
        "iam:ListPolicyTags",
        "iam:ListPolicyVersions",
        "iam:ListRolePolicies",
        "iam:ListRoleTags",
        "organizations:DescribeAccount",
        "organizations:DescribeOrganization",
        "organizations:DescribeOrganizationalUnit",
        "organizations:DescribePolicy",
        "organizations:ListAccounts",
        "organizations:ListAccountsForParent",
        "organizations:ListAWSServiceAccessForOrganization",
        "organizations:ListChildren",
        "organizations:ListOrganizationalUnitsForParent",
        "organizations:ListParents",
        "organizations:ListPolicies",
        "organizations:ListPoliciesForTarget",
        "organizations:ListRoots",
        "organizations:ListTagsForResource",
        "organizations:ListTargetsForPolicy",
        "s3:GetAccountPublicAccessBlock",
        "sns:GetTopicAttributes",
        "sns:ListTagsForResource",
        "sso:DescribePermissionSet",
        "sso:ListAccountAssignments",
        "sso:ListManagedPoliciesInPermissionSet",
        "sso:ListTagsForResource",
      ]
      resources = ["*"]
    }
  }
}

# The management account has a distinct provider from the deployment account's
# application OIDC provider. Keeping the two trust roots separate prevents an
# application workflow from gaining access to organization or foundation state.
resource "aws_iam_openid_connect_provider" "foundation_github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Component = "github-oidc"
  }

  lifecycle {
    prevent_destroy = true
  }
}

module "foundation_plan_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.0"

  name                 = "AWSFoundationTerraformPlan"
  use_name_prefix      = false
  description          = "Read-only GitHub Actions role for aws-foundation pull-request plans"
  max_session_duration = 3600

  enable_oidc             = true
  oidc_provider_urls      = ["token.actions.githubusercontent.com"]
  oidc_audiences          = ["sts.amazonaws.com"]
  oidc_subjects           = ["${local.foundation_ci_repository.subject_base}:pull_request"]
  trust_policy_conditions = local.foundation_plan_trust_conditions

  create_inline_policy      = true
  inline_policy_permissions = local.foundation_plan_permissions

  tags = {
    Application = "aws-foundation"
    Component   = "github-oidc"
  }

  depends_on = [aws_iam_openid_connect_provider.foundation_github_actions]
}
