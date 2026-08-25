variable "account_id" {
  description = "AWS account receiving the baseline."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be exactly 12 digits."
  }
}

variable "deploy_role_name" {
  description = "Exact GitHub Actions deployment role name."
  type        = string
}

variable "enable_state_access" {
  description = "Grant the OIDC roles state access after identity-only smoke tests pass."
  type        = bool
  default     = false
}

variable "environment" {
  description = "Deployment environment represented by the AWS account."
  type        = string

  validation {
    condition     = contains(["uat", "production"], var.environment)
    error_message = "environment must be uat or production."
  }
}

variable "github_actor_id" {
  description = "Optional immutable GitHub actor ID required by the deployment-role trust."
  type        = string
  default     = null
  nullable    = true
}

variable "github_environment" {
  description = "Exact GitHub Environment name in the OIDC token."
  type        = string
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID enforced in OIDC trust."
  type        = string
}

variable "github_repository_name" {
  description = "Human-readable owner/repository used for tags and documentation."
  type        = string
}

variable "github_repository_owner_id" {
  description = "Immutable GitHub repository owner ID enforced in OIDC trust."
  type        = string
}

variable "github_deploy_subject" {
  description = "Exact immutable environment-scoped GitHub OIDC deployment subject."
  type        = string
}

variable "github_plan_subject" {
  description = "Exact immutable pull-request GitHub OIDC plan subject."
  type        = string
}

variable "plan_role_name" {
  description = "Exact GitHub Actions Terraform plan role name."
  type        = string
}

variable "state_bucket_name" {
  description = "Existing empty S3 bucket imported and managed by this baseline."
  type        = string
}
