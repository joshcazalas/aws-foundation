locals {
  money_on_record_static_site_resources = {
    for environment, configuration in local.money_on_record_environments : environment => {
      bucket_arn                = "arn:aws:s3:::money-on-record-${environment}-${configuration.account_id}-site"
      distribution_arn          = "arn:aws:cloudfront::${configuration.account_id}:distribution/*"
      origin_access_control_arn = "arn:aws:cloudfront::${configuration.account_id}:origin-access-control/*"
    }
  }

  money_on_record_static_site_read_permissions = {
    for environment, resources in local.money_on_record_static_site_resources : environment => {
      ReadStaticSiteBucketConfiguration = {
        actions = [
          "s3:GetBucketLocation",
          "s3:GetBucketOwnershipControls",
          "s3:GetBucketPolicy",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketTagging",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration",
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
        resources = ["arn:aws:cloudfront::aws:cache-policy/658327ea-f89d-4fab-a63d-7e88639e58f6"]
      }
      ReadManagedCloudFrontResponseHeadersPolicy = {
        actions = [
          "cloudfront:GetResponseHeadersPolicy",
          "cloudfront:GetResponseHeadersPolicyConfig",
        ]
        resources = ["arn:aws:cloudfront::aws:response-headers-policy/67f7725c-6f97-4210-82d7-5512b31e9d03"]
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
      },
    )
  }
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
