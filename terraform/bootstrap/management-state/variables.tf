variable "aws_region" {
  description = "AWS region containing the foundation state bucket."
  type        = string
  default     = "us-east-1"
}

variable "management_account_id" {
  description = "AWS Organizations management account ID."
  type        = string
  default     = "357964519547"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "management_account_id must be exactly 12 digits."
  }
}

variable "state_bucket_name" {
  description = "Globally unique management-account foundation state bucket."
  type        = string
  default     = "joshcazalas-aws-foundation-tfstate-357964519547"
}
