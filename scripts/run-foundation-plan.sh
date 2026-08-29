#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
  echo "usage: $0 SOURCE_DIRECTORY TERRAFORM_ROOT RESULT_PARENT_DIRECTORY" >&2
  exit 64
fi

source_directory="$(realpath "$1")"
terraform_root="$2"
result_parent_directory="$(realpath -m "$3")"
script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$terraform_root" in
  terraform/bootstrap/management-state)
    result_slug="management-state"
    scopes=(management)
    ;;
  terraform/organization)
    result_slug="organization"
    scopes=(management)
    if [[ -z "${TF_VAR_account_emails:-}" ]]; then
      echo "TF_VAR_account_emails is required for the organization plan." >&2
      exit 65
    fi
    ;;
  terraform/platform)
    result_slug="platform"
    scopes=(production uat deployment)
    export TF_VAR_member_account_access_role_name="AWSFoundationTerraformPlan"
    ;;
  terraform/github)
    result_slug="github"
    scopes=(github)
    ;;
  *)
    echo "Unrecognized Terraform root: $terraform_root" >&2
    exit 64
    ;;
esac

result_directory="$result_parent_directory/$result_slug"

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
mkdir -p "$result_directory"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

plan_file="$temporary_directory/plan.tfplan"
plan_json="$temporary_directory/plan.json"
command_log="$temporary_directory/command.log"
changes_json="$temporary_directory/changes.json"
plan_digest=""

scopes_json="$(printf '%s\n' "${scopes[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')"

write_metadata() {
  local status="$1"
  local exit_code="$2"
  local phase="$3"

  jq \
    --arg root "$terraform_root" \
    --arg slug "$result_slug" \
    --arg status "$status" \
    --arg phase "$phase" \
    --arg plan_digest "$plan_digest" \
    --argjson exit_code "$exit_code" \
    --argjson scopes "$scopes_json" \
    '
      def action_count($scope; $action):
        [
          .[]
          | select(.scope == $scope)
          | select(.actions | index($action))
        ]
        | length;

      def overall_action_count($action):
        [.[] | select(.actions | index($action))] | length;

      {
        root: $root,
        slug: $slug,
        status: $status,
        phase: $phase,
        plan_digest: $plan_digest,
        exit_code: $exit_code,
        overall: {
          add: overall_action_count("create"),
          change: overall_action_count("update"),
          destroy: overall_action_count("delete")
        },
        scopes: [
          $scopes[] as $scope
          | {
              name: $scope,
              add: action_count($scope; "create"),
              change: action_count($scope; "update"),
              destroy: action_count($scope; "delete")
            }
        ],
        changes: [
          .[]
          | {
              address,
              actions,
              scope
            }
        ]
        | sort_by(.address)
      }
    ' "$changes_json" >"$result_directory/metadata.json"
}

write_failure() {
  local exit_code="$1"
  local phase="$2"

  printf '[]\n' >"$changes_json"
  if [[ -s "$command_log" ]]; then
    cp "$command_log" "$result_directory/plan.txt"
  else
    printf 'The %s phase failed before OpenTofu produced output.\n' "$phase" >"$result_directory/plan.txt"
  fi
  write_metadata failed "$exit_code" "$phase"
}

export TF_IN_AUTOMATION=1

set +e
tofu -chdir="$root_directory" init \
  -backend-config=backend.s3.tfbackend \
  -input=false \
  -lockfile=readonly \
  -no-color 2>&1 | tee "$command_log"
init_exit_code="${PIPESTATUS[0]}"
set -e

if [[ "$init_exit_code" -ne 0 ]]; then
  write_failure "$init_exit_code" init
  exit "$init_exit_code"
fi

plan_arguments=(
  -input=false
  -lock=false
  -no-color
  -detailed-exitcode
  -out="$plan_file"
)

if [[ "$terraform_root" == "terraform/github" ]]; then
  plan_arguments+=("-refresh=false")
fi

set +e
tofu -chdir="$root_directory" plan "${plan_arguments[@]}" 2>&1 | tee "$command_log"
plan_exit_code="${PIPESTATUS[0]}"
set -e

if [[ "$plan_exit_code" -ne 0 && "$plan_exit_code" -ne 2 ]]; then
  write_failure "$plan_exit_code" plan
  exit "$plan_exit_code"
fi

if ! tofu -chdir="$root_directory" show -json "$plan_file" >"$plan_json"; then
  printf 'OpenTofu created a plan, but rendering its temporary JSON representation failed.\n' >"$command_log"
  write_failure 1 render-json
  exit 1
fi

plan_digest="$(
  jq -cS -f "$script_directory/plan-review-projection.jq" "$plan_json" \
    | sha256sum \
    | cut -d' ' -f1
)"

jq \
  --arg root "$terraform_root" \
  -f "$script_directory/summarize-plan.jq" \
  "$plan_json" >"$changes_json"

if ! tofu -chdir="$root_directory" show -no-color "$plan_file" >"$result_directory/plan.txt"; then
  printf 'OpenTofu created a plan, but rendering its sanitized text representation failed.\n' >"$command_log"
  write_failure 1 render-text
  exit 1
fi

write_metadata success "$plan_exit_code" plan

# The binary plan and raw JSON remain only inside temporary_directory and are
# deleted by the EXIT trap. Only metadata and the normal redacted text view are
# handed to the comment job.
cat "$result_directory/plan.txt"
