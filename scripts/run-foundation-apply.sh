#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "usage: $0 SOURCE_DIRECTORY TERRAFORM_ROOT" >&2
  exit 64
fi

source_directory="$(realpath "$1")"
terraform_root="$2"

case "$terraform_root" in
  terraform/bootstrap/management-state)
    root_label="Management state"
    ;;
  terraform/organization)
    root_label="Organization"
    if [[ -z "${TF_VAR_account_emails:-}" ]]; then
      echo "TF_VAR_account_emails is required for the organization apply." >&2
      exit 65
    fi
    ;;
  terraform/platform)
    root_label="Platform"
    export TF_VAR_member_account_access_role_name="AWSFoundationTerraformApply"
    ;;
  *)
    echo "Unrecognized automatic foundation root: $terraform_root" >&2
    exit 64
    ;;
esac

root_directory="$(realpath -m "$source_directory/$terraform_root")"
case "$root_directory" in
  "$source_directory"/*)
    ;;
  *)
    echo "Terraform root resolves outside the checked-out source." >&2
    exit 64
    ;;
esac

if [[ ! -d "$root_directory" ]]; then
  echo "Terraform root does not exist: $terraform_root" >&2
  exit 66
fi

umask 077
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

apply_log="$temporary_directory/apply.log"
post_plan_log="$temporary_directory/post-plan.log"

export TF_IN_AUTOMATION=1

if ! tofu -chdir="$root_directory" init \
  -backend-config=backend.s3.tfbackend \
  -input=false \
  -lockfile=readonly \
  -no-color >"$apply_log" 2>&1; then
  echo "OpenTofu initialization failed for $terraform_root; use the documented local recovery path." >&2
  exit 1
fi

if ! tofu -chdir="$root_directory" apply \
  -input=false \
  -auto-approve \
  -lock-timeout=10m \
  -no-color >"$apply_log" 2>&1; then
  echo "OpenTofu apply failed for $terraform_root; use the documented local recovery path." >&2
  exit 1
fi

set +e
tofu -chdir="$root_directory" plan \
  -input=false \
  -lock-timeout=10m \
  -no-color \
  -detailed-exitcode >"$post_plan_log" 2>&1
post_plan_exit_code=$?
set -e

if [[ "$post_plan_exit_code" -ne 0 ]]; then
  echo "Post-apply convergence failed for $terraform_root with exit code $post_plan_exit_code." >&2
  exit "$post_plan_exit_code"
fi

summary_file="${GITHUB_STEP_SUMMARY:-/dev/null}"
{
  echo "### $root_label foundation apply"
  echo
  echo "| Field | Value |"
  echo "| --- | --- |"
  echo "| Commit | \`${GITHUB_SHA:-unknown}\` |"
  echo "| Actor | \`${GITHUB_ACTOR:-unknown}\` |"
  echo "| Apply | Completed |"
  echo "| Post-apply plan | No changes |"
} >>"$summary_file"
