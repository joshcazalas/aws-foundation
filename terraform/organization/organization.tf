locals {
  foundation_accounts = {
    deployment = {
      budget_amount = 5
      environment   = "deployment"
      name          = "deployment"
      parent_id     = aws_organizations_organizational_unit.deployments.id
      purpose       = "Centralized CI/CD identities and application state"
    }
    workloads-uat = {
      budget_amount = 5
      environment   = "uat"
      name          = "workloads-uat"
      parent_id     = aws_organizations_organizational_unit.nonproduction.id
      purpose       = "Shared non-production application workloads"
    }
    workloads-prod = {
      budget_amount = 10
      environment   = "prod"
      name          = "workloads-prod"
      parent_id     = aws_organizations_organizational_unit.production.id
      purpose       = "Shared production application workloads"
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

  tags = {
    ManagedBy  = "terraform"
    Repository = "joshcazalas/aws-foundation"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "deployments" {
  name      = "Deployments"
  parent_id = var.organization_root_id

  tags = {
    ManagedBy  = "terraform"
    Repository = "joshcazalas/aws-foundation"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "nonproduction" {
  name      = "NonProduction"
  parent_id = aws_organizations_organizational_unit.workloads.id

  tags = {
    Environment = "nonproduction"
    ManagedBy   = "terraform"
    Repository  = "joshcazalas/aws-foundation"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "production" {
  name      = "Production"
  parent_id = aws_organizations_organizational_unit.workloads.id

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Repository  = "joshcazalas/aws-foundation"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_account" "foundation" {
  for_each = local.foundation_accounts

  name      = each.value.name
  email     = var.account_emails[each.key]
  parent_id = each.value.parent_id
  role_name = "OrganizationAccountAccessRole"

  close_on_deletion = false

  tags = {
    Environment = each.value.environment
    ManagedBy   = "terraform"
    Purpose     = each.value.purpose
    Repository  = "joshcazalas/aws-foundation"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name]
  }
}
