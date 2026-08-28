#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "usage: $0 TERRAFORM_ROOT" >&2
  exit 64
fi

terraform_root="$1"
case "$terraform_root" in
  terraform/bootstrap/management-state|terraform/organization|terraform/platform|terraform/github)
    ;;
  *)
    echo "Unrecognized Terraform root: $terraform_root" >&2
    exit 64
    ;;
esac

temporary_data_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_data_directory"' EXIT
export TF_DATA_DIR="$temporary_data_directory"

tofu -chdir="$terraform_root" init \
  -backend=false \
  -input=false \
  -lockfile=readonly
tofu -chdir="$terraform_root" validate
