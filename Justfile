set shell := ["bash", "-euo", "pipefail", "-c"]

terraform_root := "terraform"
repo_root := justfile_directory()

fmt:
    git ls-files -z --cached --others --exclude-standard -- '{{terraform_root}}/**/*.tf' '{{terraform_root}}/**/*.tfvars' '{{terraform_root}}/**/*.tftest.hcl' | xargs -0 --no-run-if-empty tofu fmt -check

fmt-fix:
    git ls-files -z --cached --others --exclude-standard -- '{{terraform_root}}/**/*.tf' '{{terraform_root}}/**/*.tfvars' '{{terraform_root}}/**/*.tftest.hcl' | xargs -0 --no-run-if-empty tofu fmt

hygiene:
    bash scripts/check-repository-hygiene.sh

lint:
    tflint --recursive --chdir={{terraform_root}} --config={{repo_root}}/.tflint.hcl --format=compact

workflow-lint:
    actionlint
    shellcheck scripts/*.sh
    bash -n scripts/*.sh
    PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v

validate-bootstrap:
    bash scripts/validate-root.sh {{terraform_root}}/bootstrap/management-state

validate-organization:
    bash scripts/validate-root.sh {{terraform_root}}/organization

validate-github:
    bash scripts/validate-root.sh {{terraform_root}}/github

validate-platform:
    bash scripts/validate-root.sh {{terraform_root}}/platform

validate: fmt hygiene lint workflow-lint validate-bootstrap validate-organization validate-platform validate-github
