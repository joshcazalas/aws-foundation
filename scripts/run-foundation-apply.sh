#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "usage: $0 SOURCE_DIRECTORY TERRAFORM_ROOT" >&2
  exit 64
fi

source_directory="$(realpath "$1")"
terraform_root="$2"
script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$terraform_root" in
  terraform/bootstrap/management-state)
    expected_scopes='["management"]'
    root_label="Management state"
    ;;
  terraform/organization)
    expected_scopes='["management"]'
    root_label="Organization"
    if [[ -z "${TF_VAR_account_emails:-}" ]]; then
      echo "TF_VAR_account_emails is required for the organization apply." >&2
      exit 65
    fi
    ;;
  terraform/platform)
    expected_scopes='["deployment","production","uat"]'
    root_label="Platform"
    export TF_VAR_member_account_access_role_name="AWSFoundationTerraformApply"
    ;;
  *)
    echo "Unrecognized automatic foundation root: $terraform_root" >&2
    exit 64
    ;;
esac

if [[ -z "${EXPECTED_CHANGES:-}" ]]; then
  echo "EXPECTED_CHANGES is required." >&2
  exit 65
fi

if [[ ! "${PULL_REQUEST_NUMBER:-}" =~ ^[1-9][0-9]*$ ]]; then
  echo "PULL_REQUEST_NUMBER must be a positive integer." >&2
  exit 65
fi

if [[ ! "${REVIEWED_PLAN_RUN_ID:-}" =~ ^[1-9][0-9]*$ ]]; then
  echo "REVIEWED_PLAN_RUN_ID must be a positive integer." >&2
  exit 65
fi

if [[ ! "${REVIEWED_PLAN_DIGEST:-}" =~ ^[a-f0-9]{64}$ ]]; then
  echo "REVIEWED_PLAN_DIGEST must be a lowercase SHA-256 digest." >&2
  exit 65
fi

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

plan_file="$temporary_directory/foundation.tfplan"
plan_json="$temporary_directory/plan.json"
changes_json="$temporary_directory/changes.json"
plan_log="$temporary_directory/plan.log"
apply_log="$temporary_directory/apply.log"
post_plan_log="$temporary_directory/post-plan.log"

reviewed_changes="$({
  jq -ceS \
    --argjson expected_scopes "$expected_scopes" \
    '
      if type != "array" then
        error("reviewed changes must be an array")
      else
        .
      end
      | if all(.[];
          type == "object"
          and (.address | type == "string" and length > 0)
          and (.actions | type == "array" and length > 0)
          and all(.actions[]; IN("create", "delete", "update"))
          and (.scope | type == "string" and IN($expected_scopes[]))
        ) then
          [
            .[]
            | {
                address,
                actions,
                scope
              }
          ]
          | sort_by(.address)
        else
          error("reviewed changes contain an invalid action manifest")
        end
    ' <<<"$EXPECTED_CHANGES"
} 2>/dev/null)" || {
  echo "The reviewed action manifest is invalid for $terraform_root." >&2
  exit 65
}

export TF_IN_AUTOMATION=1

if ! tofu -chdir="$root_directory" init \
  -backend-config=backend.s3.tfbackend \
  -input=false \
  -lockfile=readonly \
  -no-color >"$plan_log" 2>&1; then
  echo "OpenTofu initialization failed for $terraform_root; review the protected job log." >&2
  exit 1
fi

set +e
tofu -chdir="$root_directory" plan \
  -input=false \
  -lock-timeout=10m \
  -no-color \
  -detailed-exitcode \
  -out="$plan_file" >"$plan_log" 2>&1
plan_exit_code=$?
set -e

if [[ "$plan_exit_code" -ne 0 && "$plan_exit_code" -ne 2 ]]; then
  echo "The fresh locked OpenTofu plan failed for $terraform_root." >&2
  exit "$plan_exit_code"
fi

if ! tofu -chdir="$root_directory" show -json "$plan_file" >"$plan_json"; then
  echo "OpenTofu could not render the fresh saved plan for comparison." >&2
  exit 1
fi


actual_plan_digest="$(
  jq -cS -f "$script_directory/plan-review-projection.jq" "$plan_json" \
    | sha256sum \
    | cut -d' ' -f1
)"

if [[ "$actual_plan_digest" != "$REVIEWED_PLAN_DIGEST" ]]; then
  echo "The fresh locked plan does not match the reviewed plan digest." >&2
  exit 1
fi

jq \
  --arg root "$terraform_root" \
  -f "$script_directory/summarize-plan.jq" \
  "$plan_json" >"$changes_json"

actual_changes="$(
  jq -ceS \
    '[.[] | {address, actions, scope}] | sort_by(.address)' \
    "$changes_json"
)"

if [[ "$plan_exit_code" -eq 0 && "$actual_changes" != "[]" ]] ||
  [[ "$plan_exit_code" -eq 2 && "$actual_changes" == "[]" ]]; then
  echo "OpenTofu exit status and the fresh saved plan disagree." >&2
  exit 1
fi

if [[ "$actual_changes" != "$reviewed_changes" ]]; then
  echo "The fresh locked plan does not match the exact resource/action manifest reviewed on the pull request." >&2
  exit 1
fi

manifest_sha256="$(printf '%s' "$actual_changes" | sha256sum | cut -d' ' -f1)"
change_count="$(jq 'length' <<<"$actual_changes")"
apply_result="No changes"

if [[ "$actual_changes" != "[]" ]]; then
  if ! tofu -chdir="$root_directory" apply \
    -input=false \
    -auto-approve \
    -no-color \
    "$plan_file" >"$apply_log" 2>&1; then
    echo "The exact reviewed saved plan failed during apply for $terraform_root." >&2
    exit 1
  fi
  apply_result="Applied exact saved plan"
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
  echo "| Pull request | \`#${PULL_REQUEST_NUMBER}\` |"
  echo "| Reviewed plan run | \`${REVIEWED_PLAN_RUN_ID}\` |"
  echo "| Actor | \`${GITHUB_ACTOR:-unknown}\` |"
  echo "| Reviewed actions | \`${change_count}\` |"
  echo "| Manifest SHA-256 | \`${manifest_sha256}\` |"
  echo "| Apply | $apply_result |"
  echo "| Post-apply plan | No changes |"
} >>"$summary_file"
