variable "aws_region" {
  description = "AWS region for deployment-platform resources."
  type        = string
  default     = "us-east-1"
}

variable "enable_money_on_record_state_access" {
  description = "Enable central state permissions after each environment's identity-only role-chain test passes."
  type        = map(bool)
  default = {
    production = true
    uat        = true
  }

  validation {
    condition = (
      length(var.enable_money_on_record_state_access) == 2 &&
      alltrue([for key in ["production", "uat"] : contains(keys(var.enable_money_on_record_state_access), key)])
    )
    error_message = "enable_money_on_record_state_access must contain exactly production and uat."
  }
}

variable "enable_money_on_record_workload_access" {
  description = "Enable reviewed static-site read permissions for plan roles and deployment permissions for deploy roles."
  type        = map(bool)
  default = {
    production = true
    uat        = true
  }

  validation {
    condition = (
      length(var.enable_money_on_record_workload_access) == 2 &&
      alltrue([for key in ["production", "uat"] : contains(keys(var.enable_money_on_record_workload_access), key)])
    )
    error_message = "enable_money_on_record_workload_access must contain exactly production and uat."
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

variable "member_account_access_role_name" {
  description = "Member-account role assumed by platform providers. Local applies use the Organizations bootstrap administrator; CI selects the distinct plan or apply role."
  type        = string
  default     = "OrganizationAccountAccessRole"

  validation {
    condition = contains([
      "AWSFoundationTerraformApply",
      "AWSFoundationTerraformPlan",
      "OrganizationAccountAccessRole",
    ], var.member_account_access_role_name)
    error_message = "member_account_access_role_name must be an approved foundation administration, plan, or apply role."
  }
}

variable "money_on_record_deploy_job_workflow_ref" {
  description = "Exact main-branch reusable GitHub deployment workflow ref enforced in OIDC trust."
  type        = string
  default     = "joshcazalas/money-on-record/.github/workflows/reusable-terraform-deploy.yml@refs/heads/main"

  validation {
    condition     = var.money_on_record_deploy_job_workflow_ref == "joshcazalas/money-on-record/.github/workflows/reusable-terraform-deploy.yml@refs/heads/main"
    error_message = "money_on_record_deploy_job_workflow_ref must identify the reviewed main-branch reusable deployment workflow."
  }
}

variable "money_on_record_plan_job_workflow_ref" {
  description = "Exact main-branch reusable GitHub plan workflow ref enforced in OIDC trust."
  type        = string
  default     = "joshcazalas/money-on-record/.github/workflows/reusable-terraform-plan.yml@refs/heads/main"

  validation {
    condition     = var.money_on_record_plan_job_workflow_ref == "joshcazalas/money-on-record/.github/workflows/reusable-terraform-plan.yml@refs/heads/main"
    error_message = "money_on_record_plan_job_workflow_ref must identify the reviewed main-branch reusable plan workflow."
  }
}
