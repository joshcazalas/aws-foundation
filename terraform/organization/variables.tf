variable "aws_region" {
  description = "Primary AWS region and IAM Identity Center home region."
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

variable "organization_id" {
  description = "Existing AWS Organizations organization ID."
  type        = string
  default     = "o-n0evqvouxs"
}

variable "organization_root_id" {
  description = "Existing AWS Organizations root ID."
  type        = string
  default     = "r-y37x"
}

variable "identity_center_instance_arn" {
  description = "ARN of the organization IAM Identity Center instance."
  type        = string
  default     = "arn:aws:sso:::instance/ssoins-7223f0f0b061900d"
}

variable "identity_center_principal_id" {
  description = "Identity Store ID of the human administrator receiving assignments."
  type        = string
  default     = "c44824a8-e0c1-70ef-836c-9ee7fc11c9bf"
}

variable "workload_account_emails" {
  description = "Unique account email aliases keyed like workload_accounts. Never commit the values."
  type        = map(string)
  sensitive   = true

  validation {
    condition     = alltrue([for email in values(var.workload_account_emails) : can(regex("^[^@[:space:]]+@[^@[:space:]]+$", email))])
    error_message = "Every workload account email must be a valid email address."
  }
}
