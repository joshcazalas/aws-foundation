variable "aws_region" {
  description = "AWS region for deployment-platform resources."
  type        = string
  default     = "us-east-1"
}

variable "enable_money_on_record_state_access" {
  description = "Enable central state permissions after each environment's identity-only role-chain test passes."
  type        = map(bool)
  default = {
    production = false
    uat        = false
  }

  validation {
    condition = (
      length(var.enable_money_on_record_state_access) == 2 &&
      alltrue([for key in ["production", "uat"] : contains(keys(var.enable_money_on_record_state_access), key)])
    )
    error_message = "enable_money_on_record_state_access must contain exactly production and uat."
  }
}

variable "management_account_id" {
  description = "AWS Organizations management account ID that owns foundation state."
  type        = string
  default     = "357964519547"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "management_account_id must be exactly 12 digits."
  }
}

variable "money_on_record_deploy_job_workflow_ref" {
  description = "Optional exact reusable GitHub deployment workflow ref enforced in OIDC trust after it exists."
  type        = string
  default     = null
  nullable    = true
}

variable "money_on_record_plan_job_workflow_ref" {
  description = "Optional exact reusable GitHub plan workflow ref; it must be set before state access is enabled."
  type        = string
  default     = null
  nullable    = true
}
