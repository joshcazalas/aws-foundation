output "environments" {
  description = "GitHub deployment environments and immutable repository IDs."
  value = {
    for name, environment in github_repository_environment.this : name => {
      environment   = environment.environment
      repository_id = environment.repository_id
    }
  }
}

output "repository_variables" {
  description = "Non-secret repository-level variables for centralized Terraform planning."
  value       = { for name, variable in github_actions_variable.this : name => variable.value }
}
