variable "application_name" {
  description = "Human-readable application name used in tags."
  type        = string
}

variable "deploy_role_name" {
  description = "Exact GitHub OIDC deployment hub role name."
  type        = string
}

variable "enable_state_access" {
  description = "Grant state access only after identity-only role-chain tests succeed."
  type        = bool
  default     = false
}

variable "environment" {
  description = "Deployment environment represented by this role pair."
  type        = string

  validation {
    condition     = contains(["uat", "production"], var.environment)
    error_message = "environment must be uat or production."
  }
}

variable "github_actor_id" {
  description = "Optional immutable GitHub actor ID required by deployment trust."
  type        = string
  default     = null
  nullable    = true
}

variable "github_deploy_subject" {
  description = "Exact immutable environment-scoped GitHub OIDC subject."
  type        = string
}

variable "github_deploy_job_workflow_ref" {
  description = "Optional exact reusable deployment workflow ref enforced after the workflow exists."
  type        = string
  default     = null
  nullable    = true
}

variable "github_environment" {
  description = "Exact GitHub Environment claim."
  type        = string
}

variable "github_plan_subject" {
  description = "Exact immutable pull-request GitHub OIDC subject."
  type        = string
}

variable "github_plan_job_workflow_ref" {
  description = "Optional exact reusable plan workflow ref required before state access is enabled."
  type        = string
  default     = null
  nullable    = true
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID enforced in OIDC trust."
  type        = string
}

variable "github_repository_name" {
  description = "Human-readable owner/repository used in role descriptions."
  type        = string
}

variable "github_repository_owner_id" {
  description = "Immutable GitHub repository owner ID enforced in OIDC trust."
  type        = string
}

variable "plan_role_name" {
  description = "Exact GitHub OIDC plan hub role name."
  type        = string
}

variable "state_bucket_arn" {
  description = "Central application state bucket ARN."
  type        = string
}

variable "state_object_keys" {
  description = "Exact state object keys this environment may access."
  type        = set(string)

  validation {
    condition = (
      length(var.state_object_keys) > 0 &&
      alltrue([for key in var.state_object_keys : endswith(key, "/terraform.tfstate")])
    )
    error_message = "state_object_keys must be non-empty and every key must end in /terraform.tfstate."
  }
}

variable "workload_deploy_role_arn" {
  description = "Exact workload-account deployment role this hub role may assume."
  type        = string
}

variable "workload_plan_role_arn" {
  description = "Exact workload-account plan role this hub role may assume."
  type        = string
}
