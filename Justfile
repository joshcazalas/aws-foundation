set shell := ["bash", "-euo", "pipefail", "-c"]

terraform_root := "terraform"
repo_root := justfile_directory()

fmt:
    tofu fmt -recursive -check {{terraform_root}}

fmt-fix:
    tofu fmt -recursive {{terraform_root}}

hygiene:
    bash scripts/check-repository-hygiene.sh

lint:
    tflint --recursive --chdir={{terraform_root}} --config={{repo_root}}/.tflint.hcl --format=compact

validate-bootstrap:
    tofu -chdir={{terraform_root}}/bootstrap/management-state init -backend=false -input=false -lockfile=readonly
    tofu -chdir={{terraform_root}}/bootstrap/management-state validate

validate-organization:
    tofu -chdir={{terraform_root}}/organization init -backend=false -input=false -lockfile=readonly
    tofu -chdir={{terraform_root}}/organization validate

validate-github:
    tofu -chdir={{terraform_root}}/github init -backend=false -input=false -lockfile=readonly
    tofu -chdir={{terraform_root}}/github validate

validate-platform:
    tofu -chdir={{terraform_root}}/platform init -backend=false -input=false -lockfile=readonly
    tofu -chdir={{terraform_root}}/platform validate

validate: fmt hygiene lint validate-bootstrap validate-organization validate-platform validate-github
