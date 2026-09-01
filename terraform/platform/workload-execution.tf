locals {
  money_on_record_static_site_resources = {
    for environment, configuration in local.money_on_record_environments : environment => {
      account_id                  = configuration.account_id
      bucket_arn                  = "arn:aws:s3:::money-on-record-${environment}-${configuration.account_id}-site"
      distribution_arn            = "arn:aws:cloudfront::${configuration.account_id}:distribution/*"
      origin_access_control_arn   = "arn:aws:cloudfront::${configuration.account_id}:origin-access-control/*"
      response_headers_policy_arn = "arn:aws:cloudfront::${configuration.account_id}:response-headers-policy/*"
    }
  }

  money_on_record_static_site_read_permissions = {
    for environment, resources in local.money_on_record_static_site_resources : environment => {
      ReadStaticSiteBucketConfiguration = {
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
        resources = [resources.bucket_arn]
      }
      # CloudFront's managed-policy discovery APIs do not support resource ARNs.
      DiscoverManagedCloudFrontPolicies = {
        actions = [
          "cloudfront:ListCachePolicies",
          "cloudfront:ListResponseHeadersPolicies",
        ]
        resources = ["*"]
      }
      ReadManagedCloudFrontCachePolicy = {
        actions = [
          "cloudfront:GetCachePolicy",
          "cloudfront:GetCachePolicyConfig",
        ]
        resources = ["arn:aws:cloudfront::${resources.account_id}:cache-policy/658327ea-f89d-4fab-a63d-7e88639e58f6"]
      }
      ReadManagedCloudFrontResponseHeadersPolicy = {
        actions = [
          "cloudfront:GetResponseHeadersPolicy",
          "cloudfront:GetResponseHeadersPolicyConfig",
        ]
        resources = ["arn:aws:cloudfront::${resources.account_id}:response-headers-policy/67f7725c-6f97-4210-82d7-5512b31e9d03"]
      }
      ReadStaticSiteResponseHeadersPolicies = {
        actions = [
          "cloudfront:GetResponseHeadersPolicy",
          "cloudfront:GetResponseHeadersPolicyConfig",
        ]
        resources = [resources.response_headers_policy_arn]
      }
      ReadStaticSiteDistribution = {
        actions = [
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:ListTagsForResource",
        ]
        resources = [resources.distribution_arn]
        condition = [
          {
            test     = "StringEquals"
            variable = "aws:ResourceTag/Project"
            values   = ["money-on-record"]
          },
          {
            test     = "StringEquals"
            variable = "aws:ResourceTag/Environment"
            values   = [environment]
          },
        ]
      }
      ReadStaticSiteOriginAccessControl = {
        actions = [
          "cloudfront:GetOriginAccessControl",
          "cloudfront:GetOriginAccessControlConfig",
        ]
        resources = [resources.origin_access_control_arn]
      }
    }
  }

  money_on_record_static_site_deploy_permissions = {
    for environment, resources in local.money_on_record_static_site_resources : environment => merge(
      local.money_on_record_static_site_read_permissions[environment],
      {
        ManageStaticSiteBucket = {
          actions = [
            "s3:CreateBucket",
            "s3:DeleteBucket",
            "s3:DeleteBucketPolicy",
            "s3:PutBucketOwnershipControls",
            "s3:PutBucketPolicy",
            "s3:PutBucketPublicAccessBlock",
            "s3:PutBucketTagging",
            "s3:PutBucketVersioning",
            "s3:PutEncryptionConfiguration",
            "s3:TagResource",
            "s3:UntagResource",
          ]
          resources = [resources.bucket_arn]
        }
        # Distribution creation has no resource ARN yet, so require both
        # immutable boundary tags in the request.
        CreateTaggedStaticSiteDistribution = {
          actions = [
            "cloudfront:CreateDistribution",
            "cloudfront:TagResource",
          ]
          resources = ["*"]
          condition = [
            {
              test     = "StringEquals"
              variable = "aws:RequestTag/Project"
              values   = ["money-on-record"]
            },
            {
              test     = "StringEquals"
              variable = "aws:RequestTag/Environment"
              values   = [environment]
            },
          ]
        }
        ManageStaticSiteDistribution = {
          actions = [
            "cloudfront:DeleteDistribution",
            "cloudfront:UpdateDistribution",
          ]
          resources = [resources.distribution_arn]
          condition = [
            {
              test     = "StringEquals"
              variable = "aws:ResourceTag/Project"
              values   = ["money-on-record"]
            },
            {
              test     = "StringEquals"
              variable = "aws:ResourceTag/Environment"
              values   = [environment]
            },
          ]
        }
        TagStaticSiteDistribution = {
          actions   = ["cloudfront:TagResource"]
          resources = [resources.distribution_arn]
          condition = [
            {
              test     = "StringEquals"
              variable = "aws:ResourceTag/Project"
              values   = ["money-on-record"]
            },
            {
              test     = "StringEquals"
              variable = "aws:ResourceTag/Environment"
              values   = [environment]
            },
            {
              test     = "StringEqualsIfExists"
              variable = "aws:RequestTag/Project"
              values   = ["money-on-record"]
            },
            {
              test     = "StringEqualsIfExists"
              variable = "aws:RequestTag/Environment"
              values   = [environment]
            },
          ]
        }
        UntagStaticSiteDistribution = {
          actions   = ["cloudfront:UntagResource"]
          resources = [resources.distribution_arn]
          condition = [
            {
              test     = "StringEquals"
              variable = "aws:ResourceTag/Project"
              values   = ["money-on-record"]
            },
            {
              test     = "StringEquals"
              variable = "aws:ResourceTag/Environment"
              values   = [environment]
            },
            {
              test     = "ForAllValues:StringNotEquals"
              variable = "aws:TagKeys"
              values = [
                "Environment",
                "Project",
              ]
            },
          ]
        }
        # Origin access controls cannot be tagged, and their create action does
        # not support resource-level permissions. Existing controls are still
        # restricted to the target workload account below.
        CreateStaticSiteOriginAccessControl = {
          actions   = ["cloudfront:CreateOriginAccessControl"]
          resources = ["*"]
        }
        ManageStaticSiteOriginAccessControl = {
          actions = [
            "cloudfront:DeleteOriginAccessControl",
            "cloudfront:UpdateOriginAccessControl",
          ]
          resources = [resources.origin_access_control_arn]
        }
        # Response headers policies cannot be tagged. Creation is unscoped by
        # AWS, while updates and deletion remain in the target workload account.
        CreateStaticSiteResponseHeadersPolicy = {
          actions   = ["cloudfront:CreateResponseHeadersPolicy"]
          resources = ["*"]
        }
        ManageStaticSiteResponseHeadersPolicy = {
          actions = [
            "cloudfront:DeleteResponseHeadersPolicy",
            "cloudfront:UpdateResponseHeadersPolicy",
          ]
          resources = [resources.response_headers_policy_arn]
        }
      },
    )
  }
}

locals {
  money_on_record_uat_artifact_resources = {
    bucket_arn       = "arn:aws:s3:::money-on-record-uat-${local.account_ids["workloads-uat"]}-site"
    distribution_arn = "arn:aws:cloudfront::${local.account_ids["workloads-uat"]}:distribution/EEZ2CUTI93E10"
  }
}

module "money_on_record_uat_artifact_publish_workload_role" {
  providers = {
    aws = aws.workloads_uat
  }

  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.0"

  name                 = local.money_on_record_uat_artifact_publisher.workload_role_name
  use_name_prefix      = false
  description          = "UAT site artifact publishing role for Money on Record"
  max_session_duration = 3600

  trust_policy_permissions = {
    AllowArtifactPublishingHub = {
      actions = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]
      principals = [{
        type        = "AWS"
        identifiers = [module.money_on_record_uat_artifact_publish_hub_role.arn]
      }]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = {
    ListPublishedSite = {
      actions   = ["s3:ListBucket"]
      resources = [local.money_on_record_uat_artifact_resources.bucket_arn]
      condition = [{
        test     = "StringLike"
        variable = "s3:prefix"
        values   = ["", "*"]
      }]
    }
    ManagePublishedSiteObjects = {
      actions = [
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:PutObject",
      ]
      resources = ["${local.money_on_record_uat_artifact_resources.bucket_arn}/*"]
    }
    InvalidatePublishedSite = {
      actions = [
        "cloudfront:CreateInvalidation",
        "cloudfront:GetInvalidation",
      ]
      resources = [local.money_on_record_uat_artifact_resources.distribution_arn]
    }
  }

  tags = {
    Application = "money-on-record"
    Component   = "artifact-publishing"
    Environment = "uat"
  }

  depends_on = [
    module.foundation_apply_uat,
    module.workloads_uat,
  ]
}

module "workloads_uat" {
  providers = {
    aws = aws.workloads_uat
  }

  source = "../modules/workload-execution-baseline"

  account_id       = local.account_ids["workloads-uat"]
  application_name = "money-on-record"
  environment      = "uat"

  hub_plan_role_arn   = "arn:aws:iam::${local.account_ids["deployment"]}:role/MoneyOnRecordPlanUat"
  hub_deploy_role_arn = "arn:aws:iam::${local.account_ids["deployment"]}:role/MoneyOnRecordDeployUat"

  plan_role_name   = "MoneyOnRecordTerraformPlan"
  deploy_role_name = "MoneyOnRecordTerraformDeploy"

  plan_role_policy_permissions = {
    for key, permission in local.money_on_record_static_site_read_permissions["uat"] :
    key => permission if var.enable_money_on_record_workload_access["uat"]
  }
  deploy_role_policy_permissions = {
    for key, permission in local.money_on_record_static_site_deploy_permissions["uat"] :
    key => permission if var.enable_money_on_record_workload_access["uat"]
  }

  depends_on = [module.money_on_record_hub_roles["uat"]]
}

module "workloads_production" {
  providers = {
    aws = aws.workloads_production
  }

  source = "../modules/workload-execution-baseline"

  account_id       = local.account_ids["workloads-prod"]
  application_name = "money-on-record"
  environment      = "production"

  hub_plan_role_arn   = "arn:aws:iam::${local.account_ids["deployment"]}:role/MoneyOnRecordPlanProd"
  hub_deploy_role_arn = "arn:aws:iam::${local.account_ids["deployment"]}:role/MoneyOnRecordDeployProd"

  plan_role_name   = "MoneyOnRecordTerraformPlan"
  deploy_role_name = "MoneyOnRecordTerraformDeploy"

  plan_role_policy_permissions = {
    for key, permission in local.money_on_record_static_site_read_permissions["production"] :
    key => permission if var.enable_money_on_record_workload_access["production"]
  }
  deploy_role_policy_permissions = {
    for key, permission in local.money_on_record_static_site_deploy_permissions["production"] :
    key => permission if var.enable_money_on_record_workload_access["production"]
  }

  depends_on = [module.money_on_record_hub_roles["production"]]
}
