set shell := ["bash", "-euo", "pipefail", "-c"]

terraform_root := "terraform"
repo_root := justfile_directory()

fmt:
    tofu fmt -recursive -check {{terraform_root}}

fmt-fix:
    tofu fmt -recursive {{terraform_root}}

lint:
    tflint --recursive --chdir={{terraform_root}} --config={{repo_root}}/.tflint.hcl --format=compact

validate-bootstrap:
    tofu -chdir={{terraform_root}}/bootstrap/management-state init -backend=false -input=false -lockfile=readonly
    tofu -chdir={{terraform_root}}/bootstrap/management-state validate

validate-organization:
    tofu -chdir={{terraform_root}}/organization init -backend=false -input=false -lockfile=readonly
    tofu -chdir={{terraform_root}}/organization validate

validate-uat:
    tofu -chdir={{terraform_root}}/accounts/money-on-record-uat init -backend=false -input=false -lockfile=readonly
    tofu -chdir={{terraform_root}}/accounts/money-on-record-uat validate

validate-prod:
    tofu -chdir={{terraform_root}}/accounts/money-on-record-prod init -backend=false -input=false -lockfile=readonly
    tofu -chdir={{terraform_root}}/accounts/money-on-record-prod validate

validate: fmt lint validate-bootstrap validate-organization validate-uat validate-prod
