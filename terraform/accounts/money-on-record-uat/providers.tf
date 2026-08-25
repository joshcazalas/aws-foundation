provider "aws" {
  region = "us-east-1"

  allowed_account_ids = ["732006412638"]

  default_tags {
    tags = {
      Environment = "uat"
      ManagedBy   = "terraform"
      Project     = "money-on-record"
      Repository  = "joshcazalas/aws-foundation"
    }
  }
}
