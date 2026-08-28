variable "additional_read_permissions" {
  description = "Additional control-plane read permissions required by foundation resources in this account."
  type = map(object({
    actions   = list(string)
    resources = list(string)
  }))
  default = {}
}

variable "management_plan_role_arn" {
  description = "Management-account foundation plan role allowed to assume this role."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/AWSFoundationTerraformPlan$", var.management_plan_role_arn))
    error_message = "management_plan_role_arn must identify the AWSFoundationTerraformPlan role in a 12-digit AWS account."
  }
}

variable "role_name" {
  description = "Name of the member-account read-only foundation plan role."
  type        = string
  default     = "AWSFoundationTerraformPlan"

  validation {
    condition     = var.role_name == "AWSFoundationTerraformPlan"
    error_message = "The foundation member-account plan role name is intentionally fixed."
  }
}
