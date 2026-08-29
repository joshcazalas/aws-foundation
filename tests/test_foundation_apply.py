import hashlib
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
APPLY_SCRIPT = REPOSITORY_ROOT / "scripts" / "run-foundation-apply.sh"


class FoundationApplyPolicyTests(unittest.TestCase):
    def test_management_apply_trust_is_main_only_and_immutable(self) -> None:
        source = (REPOSITORY_ROOT / "terraform/organization/foundation-apply.tf").read_text(
            encoding="utf-8"
        )

        self.assertIn(
            "joshcazalas/aws-foundation/.github/workflows/"
            "reusable-foundation-apply.yml@refs/heads/main",
            source,
        )
        self.assertIn(
            "joshcazalas/aws-foundation/.github/workflows/"
            "foundation-apply.yml@refs/heads/main",
            (
                REPOSITORY_ROOT / ".github/workflows/reusable-foundation-apply.yml"
            ).read_text(encoding="utf-8"),
        )
        self.assertIn(
            '${local.foundation_ci_repository.subject_base}:ref:refs/heads/main', source
        )
        self.assertIn("token.actions.githubusercontent.com:actor_id", source)
        self.assertIn("token.actions.githubusercontent.com:repository_id", source)
        self.assertIn("token.actions.githubusercontent.com:repository_owner_id", source)
        self.assertIn("token.actions.githubusercontent.com:job_workflow_ref", source)
        self.assertIn("token.actions.githubusercontent.com:workflow", source)
        self.assertIn('management_state = "AWSFoundationManagementStateApply"', source)
        self.assertIn('organization     = "AWSFoundationOrganizationApply"', source)
        self.assertIn('platform         = "AWSFoundationPlatformApply"', source)
        self.assertNotIn("AdministratorAccess", source)
        self.assertNotIn('"s3:*"', source)
        self.assertNotIn('"iam:*"', source)
        self.assertNotIn('"organizations:*"', source)
        self.assertNotIn('"budgets:CreateBudget"', source)
        self.assertNotIn('"budgets:DeleteBudget"', source)
        self.assertNotIn('"s3:DeleteBucketTagging"', source)
        self.assertNotIn('"s3:DeleteEncryptionConfiguration"', source)
        self.assertIn('"budgets:ModifyBudget"', source)
        self.assertIn('"aws-portal:ModifyBilling"', source)
        self.assertIn('"sso:DescribeAccountAssignmentCreationStatus"', source)
        self.assertIn('"sso:DescribePermissionSetProvisioningStatus"', source)

    def test_apply_state_permissions_are_root_specific(self) -> None:
        source = (REPOSITORY_ROOT / "terraform/organization/foundation-apply.tf").read_text(
            encoding="utf-8"
        )

        self.assertIn('"aws-foundation/platform/terraform.tfstate"', source)
        self.assertIn('"aws-foundation/organization/terraform.tfstate"', source)
        self.assertIn('"aws-foundation/management-state/terraform.tfstate"', source)
        self.assertNotIn("aws-foundation/github/terraform.tfstate", source)
        self.assertNotIn("joshcazalas-deployment-tfstate", source)
        self.assertIn('resources = ["${local.foundation_state_bucket_arn}/${config.key}"]', source)
        self.assertIn('resources = ["${local.foundation_state_bucket_arn}/${config.key}.tflock"]', source)

    def test_member_apply_roles_manage_control_plane_only(self) -> None:
        module_source = (
            REPOSITORY_ROOT / "terraform/modules/foundation-account-apply-role/main.tf"
        ).read_text(encoding="utf-8")
        platform_source = (
            REPOSITORY_ROOT / "terraform/platform/foundation-ci.tf"
        ).read_text(encoding="utf-8")

        self.assertIn("AWSFoundationPlatformApply", platform_source)
        self.assertIn("AWSFoundationTerraformApply", platform_source)
        self.assertIn("ManageReviewedIAMRoles", module_source)
        self.assertIn("ManageReviewedOIDCProviders", module_source)
        self.assertIn("ManageReviewedBucketConfiguration", module_source)
        self.assertNotIn('"s3:GetObject"', module_source)
        self.assertNotIn('"s3:PutObject"', module_source)
        self.assertNotIn("cloudfront:", module_source)
        self.assertNotIn("AdministratorAccess", module_source)


class FoundationApplyWorkflowTests(unittest.TestCase):
    def test_reusable_workflow_is_inert_until_a_trusted_caller_exists(self) -> None:
        source = (
            REPOSITORY_ROOT / ".github/workflows/reusable-foundation-apply.yml"
        ).read_text(encoding="utf-8")

        self.assertIn("workflow_call:", source)
        self.assertNotIn("pull_request:", source)
        self.assertNotIn("workflow_dispatch:", source)
        self.assertIn("cancel-in-progress: false", source)
        self.assertIn("github.event.pull_request.merged", source)
        self.assertIn("github.event.pull_request.merge_commit_sha", source)
        self.assertIn("github.actor_id", source)
        self.assertIn("github.workflow_ref", source)
        self.assertIn("refs/heads/main", source)
        self.assertIn("AWSFoundationManagementStateApply", source)
        self.assertIn("AWSFoundationOrganizationApply", source)
        self.assertIn("AWSFoundationPlatformApply", source)
        self.assertIn("contents: read", source)
        self.assertIn("id-token: write", source)
        self.assertNotIn("terraform/github", source)
        self.assertNotIn("upload-artifact", source)

    def test_apply_script_uses_fresh_locked_plan_and_convergence_check(self) -> None:
        source = APPLY_SCRIPT.read_text(encoding="utf-8")

        self.assertIn("-lock-timeout=10m", source)
        self.assertIn("-detailed-exitcode", source)
        self.assertIn('"$plan_file"', source)
        self.assertIn("AWSFoundationTerraformApply", source)
        self.assertIn("does not match the exact resource/action manifest", source)
        self.assertIn("Post-apply convergence failed", source)
        self.assertNotIn("terraform/github", source)
        self.assertNotIn("-lock=false", source)


class FoundationApplyRunnerTests(unittest.TestCase):
    def run_apply(
        self,
        plan: dict[str, object],
        expected_changes: list[dict[str, object]],
        *,
        plan_exit_code: int,
        plan_digest: str | None = None,
    ) -> tuple[subprocess.CompletedProcess[str], str, str]:
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary_path = Path(temporary_directory)
            source = temporary_path / "source"
            (source / "terraform/platform").mkdir(parents=True)

            fake_bin = temporary_path / "bin"
            fake_bin.mkdir()
            fake_tofu = fake_bin / "tofu"
            fake_tofu.write_text(
                """#!/usr/bin/env bash
set -euo pipefail

command_name=""
for argument in "$@"; do
  case "$argument" in
    init|plan|show|apply)
      command_name="$argument"
      break
      ;;
  esac
done

case "$command_name" in
  init)
    exit 0
    ;;
  plan)
    count="$(cat "$FAKE_PLAN_COUNT")"
    if [[ "$count" == "0" ]]; then
      printf '1\n' >"$FAKE_PLAN_COUNT"
      for argument in "$@"; do
        case "$argument" in
          -out=*)
            : >"${argument#-out=}"
            ;;
        esac
      done
      exit "$FAKE_PLAN_EXIT_CODE"
    fi
    printf '2\n' >"$FAKE_PLAN_COUNT"
    exit 0
    ;;
  show)
    cat "$FAKE_PLAN_JSON"
    ;;
  apply)
    printf 'apply\n' >>"$FAKE_CALLS"
    ;;
  *)
    exit 64
    ;;
esac
""",
                encoding="utf-8",
            )
            fake_tofu.chmod(0o755)

            plan_path = temporary_path / "plan.json"
            plan_path.write_text(json.dumps(plan), encoding="utf-8")
            projection = subprocess.run(
                [
                    "jq",
                    "-cS",
                    "-f",
                    str(REPOSITORY_ROOT / "scripts/plan-review-projection.jq"),
                    str(plan_path),
                ],
                check=True,
                capture_output=True,
                text=True,
            ).stdout
            computed_plan_digest = hashlib.sha256(projection.encode()).hexdigest()
            plan_count = temporary_path / "plan-count"
            plan_count.write_text("0\n", encoding="utf-8")
            calls = temporary_path / "calls"
            calls.write_text("", encoding="utf-8")
            summary = temporary_path / "summary"

            environment = os.environ | {
                "EXPECTED_CHANGES": json.dumps(expected_changes),
                "FAKE_CALLS": str(calls),
                "FAKE_PLAN_COUNT": str(plan_count),
                "FAKE_PLAN_EXIT_CODE": str(plan_exit_code),
                "FAKE_PLAN_JSON": str(plan_path),
                "GITHUB_ACTOR": "joshcazalas",
                "GITHUB_SHA": "a" * 40,
                "GITHUB_STEP_SUMMARY": str(summary),
                "PATH": f"{fake_bin}:{os.environ['PATH']}",
                "PULL_REQUEST_NUMBER": "42",
                "REVIEWED_PLAN_RUN_ID": "1234",
                "REVIEWED_PLAN_DIGEST": plan_digest or computed_plan_digest,
            }
            completed = subprocess.run(
                ["bash", str(APPLY_SCRIPT), str(source), "terraform/platform"],
                check=False,
                capture_output=True,
                env=environment,
                text=True,
            )

            return (
                completed,
                calls.read_text(encoding="utf-8"),
                summary.read_text(encoding="utf-8") if summary.exists() else "",
            )

    def test_matching_manifest_applies_and_converges(self) -> None:
        address = "module.workloads_uat.module.deploy_role.aws_iam_role_policy.inline[0]"
        plan = {
            "resource_changes": [
                {"address": address, "change": {"actions": ["update"]}},
            ]
        }
        expected = [{"address": address, "actions": ["update"], "scope": "uat"}]

        completed, calls, summary = self.run_apply(plan, expected, plan_exit_code=2)

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(calls, "apply\n")
        self.assertIn("Applied exact saved plan", summary)
        self.assertIn("Post-apply plan | No changes", summary)

    def test_manifest_mismatch_stops_before_apply(self) -> None:
        plan = {
            "resource_changes": [
                {
                    "address": "module.workloads_production.module.plan_role.aws_iam_role.this",
                    "change": {"actions": ["update"]},
                },
            ]
        }

        completed, calls, _ = self.run_apply(plan, [], plan_exit_code=2)

        self.assertNotEqual(completed.returncode, 0)
        self.assertEqual(calls, "")
        self.assertIn("does not match the exact resource/action manifest", completed.stderr)

    def test_digest_mismatch_stops_before_apply(self) -> None:
        plan = {
            "resource_changes": [
                {
                    "address": "module.workloads_uat.module.plan_role.aws_iam_role.this",
                    "change": {"actions": ["update"]},
                },
            ]
        }
        expected = [
            {
                "address": "module.workloads_uat.module.plan_role.aws_iam_role.this",
                "actions": ["update"],
                "scope": "uat",
            }
        ]

        completed, calls, _ = self.run_apply(
            plan,
            expected,
            plan_exit_code=2,
            plan_digest="0" * 64,
        )

        self.assertNotEqual(completed.returncode, 0)
        self.assertEqual(calls, "")
        self.assertIn("does not match the reviewed plan digest", completed.stderr)

    def test_no_change_manifest_skips_apply_and_proves_convergence(self) -> None:
        completed, calls, summary = self.run_apply(
            {"resource_changes": []}, [], plan_exit_code=0
        )

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(calls, "")
        self.assertIn("Apply | No changes", summary)
        self.assertIn("Post-apply plan | No changes", summary)


if __name__ == "__main__":
    unittest.main()
