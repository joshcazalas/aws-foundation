data "terraform_remote_state" "organization" {
  backend = "s3"

  config = {
    bucket              = "joshcazalas-aws-foundation-tfstate-357964519547"
    key                 = "aws-foundation/organization/terraform.tfstate"
    region              = "us-east-1"
    encrypt             = true
    use_lockfile        = true
    allowed_account_ids = ["357964519547"]
  }
}
