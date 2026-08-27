variable "account_id" {
  description = "AWS account receiving the execution-role baseline."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be exactly 12 digits."
  }
}

variable "application_name" {
  description = "Human-readable application name used in descriptions and tags."
  type        = string
}

variable "deploy_role_name" {
  description = "Exact workload-account Terraform deployment role name."
  type        = string
}

variable "environment" {
  description = "Deployment environment represented by the workload account."
  type        = string

  validation {
    condition     = contains(["uat", "production"], var.environment)
    error_message = "environment must be uat or production."
  }
}

variable "hub_deploy_role_arn" {
  description = "Exact deployment-account role allowed to assume the workload deployment role."
  type        = string
}

variable "hub_plan_role_arn" {
  description = "Exact deployment-account role allowed to assume the workload plan role."
  type        = string
}

variable "plan_role_name" {
  description = "Exact workload-account Terraform plan role name."
  type        = string
}

variable "plan_role_policy_permissions" {
  description = "Reviewed read-only IAM policy statements attached to the workload plan role."
  type = map(object({
    actions   = list(string)
    resources = list(string)
    condition = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  default = {}
}

variable "deploy_role_policy_permissions" {
  description = "Reviewed IAM policy statements attached to the workload deployment role."
  type = map(object({
    actions   = list(string)
    resources = list(string)
    condition = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  default = {}
}
