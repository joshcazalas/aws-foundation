terraform {
  backend "s3" {
    bucket              = "money-on-record-uat-732006412638-tfstate"
    key                 = "bootstrap/terraform.tfstate"
    region              = "us-east-1"
    encrypt             = true
    use_lockfile        = true
    allowed_account_ids = ["732006412638"]
  }
}
