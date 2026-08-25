locals {
  foundation_full_aws_access_targets = {
    management = var.management_account_id
    root       = var.organization_root_id
    workloads  = aws_organizations_organizational_unit.workloads.id
  }

  full_aws_access_targets = merge(
    local.foundation_full_aws_access_targets,
    { for key, account in aws_organizations_account.workload : key => account.id },
  )
}

resource "aws_organizations_policy" "default_security" {
  name        = "default-aws-security"
  description = "Adds default aws security policy blocking accounts from leaving orgs or deleting themselves. AWS adds this by defaults to accounts created after July 10th, 2026 but some accounts here predate that"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DefaultSecurityControls"
        Effect = "Deny"
        Action = [
          "organizations:LeaveOrganization",
          "account:CloseAccount",
        ]
        Resource = "*"
      },
    ]
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_policy_attachment" "default_security_root" {
  policy_id = aws_organizations_policy.default_security.id
  target_id = var.organization_root_id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_policy_attachment" "full_aws_access" {
  for_each = local.full_aws_access_targets

  policy_id = "p-FullAWSAccess"
  target_id = each.value

  lifecycle {
    prevent_destroy = true
  }
}
