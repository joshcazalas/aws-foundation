terraform {
  backend "s3" {
    bucket              = "money-on-record-prod-134604497564-tfstate"
    key                 = "bootstrap/terraform.tfstate"
    region              = "us-east-1"
    encrypt             = true
    use_lockfile        = true
    allowed_account_ids = ["134604497564"]
  }
}
