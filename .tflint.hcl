tflint {
  required_version = "= 0.64.0"
}

config {
  call_module_type    = "local"
  disabled_by_default = false
  force               = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.48.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
