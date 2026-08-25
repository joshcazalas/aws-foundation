provider "aws" {
  region = "us-east-1"

  allowed_account_ids = ["134604497564"]

  default_tags {
    tags = {
      Environment = "prod"
      ManagedBy   = "terraform"
      Project     = "money-on-record"
      Repository  = "joshcazalas/aws-foundation"
    }
  }
}
