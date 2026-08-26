data "terraform_remote_state" "organization" {
  backend = "s3"

  config = {
    bucket              = "joshcazalas-aws-foundation-tfstate-357964519547"
    key                 = "aws-foundation/organization/terraform.tfstate"
    region              = var.aws_region
    encrypt             = true
    use_lockfile        = true
    allowed_account_ids = [var.management_account_id]
  }
}

locals {
  account_ids = data.terraform_remote_state.organization.outputs.account_ids
}
