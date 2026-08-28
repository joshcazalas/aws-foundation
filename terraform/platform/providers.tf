provider "aws" {
  alias  = "deployment"
  region = var.aws_region

  allowed_account_ids = [local.account_ids["deployment"]]

  assume_role {
    role_arn     = "arn:aws:iam::${local.account_ids["deployment"]}:role/OrganizationAccountAccessRole"
    session_name = "aws-foundation-platform"
  }

  default_tags {
    tags = {
      ManagedBy  = "terraform"
      Repository = "joshcazalas/aws-foundation"
    }
  }
}

provider "aws" {
  alias  = "workloads_uat"
  region = var.aws_region

  allowed_account_ids = [local.account_ids["workloads-uat"]]

  assume_role {
    role_arn     = "arn:aws:iam::${local.account_ids["workloads-uat"]}:role/OrganizationAccountAccessRole"
    session_name = "aws-foundation-platform"
  }

  default_tags {
    tags = {
      Environment = "uat"
      ManagedBy   = "terraform"
      Repository  = "joshcazalas/aws-foundation"
    }
  }
}

provider "aws" {
  alias  = "workloads_production"
  region = var.aws_region

  allowed_account_ids = [local.account_ids["workloads-prod"]]

  assume_role {
    role_arn     = "arn:aws:iam::${local.account_ids["workloads-prod"]}:role/OrganizationAccountAccessRole"
    session_name = "aws-foundation-platform"
  }

  default_tags {
    tags = {
      Environment = "production"
      ManagedBy   = "terraform"
      Repository  = "joshcazalas/aws-foundation"
    }
  }
}
