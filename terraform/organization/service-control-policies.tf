locals {
  # These direct attachments already exist and are imported. AWS automatically
  # attaches FullAWSAccess when it creates every new OU and account, so trying
  # to create those generated attachments during the same apply is unsafe.
  full_aws_access_targets = {
    management     = var.management_account_id
    root           = var.organization_root_id
    workloads      = aws_organizations_organizational_unit.workloads.id
    workloads-prod = aws_organizations_account.foundation["workloads-prod"].id
    workloads-uat  = aws_organizations_account.foundation["workloads-uat"].id
  }
}

resource "aws_organizations_policy" "default_security" {
  name        = "default-aws-security"
  description = "Preserves AWS default security controls that prevent member accounts from leaving the organization or closing themselves"
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
