output "environments" {
  description = "GitHub deployment environments and immutable repository IDs."
  value = {
    for name, environment in github_repository_environment.this : name => {
      environment   = environment.environment
      repository_id = environment.repository_id
    }
  }
}
