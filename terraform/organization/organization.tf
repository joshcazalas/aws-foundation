locals {
  workload_accounts = {
    money-on-record-uat = {
      budget_amount = 5
      environment   = "uat"
      name          = "money-on-record-uat"
    }
    money-on-record-prod = {
      budget_amount = 10
      environment   = "prod"
      name          = "money-on-record-prod"
    }
  }
}

resource "aws_organizations_organization" "foundation" {
  feature_set = "ALL"

  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]
  aws_service_access_principals = [
    "iam.amazonaws.com",
    "sso.amazonaws.com",
  ]

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = var.organization_id == "o-n0evqvouxs"
      error_message = "Refusing to manage an unexpected AWS Organization."
    }
  }
}

resource "aws_iam_organizations_features" "centralized_root_access" {
  enabled_features = [
    "RootCredentialsManagement",
    "RootSessions",
  ]

  depends_on = [aws_organizations_organization.foundation]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = var.organization_root_id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_account" "workload" {
  for_each = local.workload_accounts

  name      = each.value.name
  email     = var.workload_account_emails[each.key]
  parent_id = aws_organizations_organizational_unit.workloads.id
  role_name = "OrganizationAccountAccessRole"

  close_on_deletion = false

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name]
  }
}
