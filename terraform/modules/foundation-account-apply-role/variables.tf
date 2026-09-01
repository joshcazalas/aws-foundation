variable "management_apply_role_arn" {
  description = "Exact management-account platform apply role allowed to assume this role."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/AWSFoundationPlatformApply$", var.management_apply_role_arn))
    error_message = "management_apply_role_arn must identify AWSFoundationPlatformApply in a 12-digit AWS account."
  }
}

variable "managed_bucket_arns" {
  description = "Exact Terraform-managed bucket ARNs whose control-plane configuration this role may mutate."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.managed_bucket_arns : can(regex("^arn:aws:s3:::[a-z0-9.-]+$", arn))])
    error_message = "managed_bucket_arns must contain only exact S3 bucket ARNs."
  }
}

variable "managed_oidc_provider_arns" {
  description = "Exact Terraform-managed IAM OIDC provider ARNs this role may mutate."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.managed_oidc_provider_arns :
      can(regex("^arn:aws:iam::[0-9]{12}:oidc-provider/token[.]actions[.]githubusercontent[.]com$", arn))
    ])
    error_message = "managed_oidc_provider_arns may contain only the exact GitHub Actions provider ARN."
  }
}

variable "managed_role_arns" {
  description = "Exact Terraform-managed IAM roles this role may create, update, or delete."
  type        = list(string)

  validation {
    condition = (
      length(var.managed_role_arns) > 0 &&
      alltrue([for arn in var.managed_role_arns : can(regex("^arn:aws:iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_-]+$", arn))])
    )
    error_message = "managed_role_arns must be non-empty and contain only exact IAM role ARNs."
  }
}

variable "role_name" {
  description = "Name of the member-account foundation apply role."
  type        = string
  default     = "AWSFoundationTerraformApply"

  validation {
    condition     = var.role_name == "AWSFoundationTerraformApply"
    error_message = "The member-account foundation apply role name is intentionally fixed."
  }
}
