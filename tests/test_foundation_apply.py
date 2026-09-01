from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
APPLY_SCRIPT = REPOSITORY_ROOT / "scripts" / "run-foundation-apply.sh"


class FoundationApplyPolicyTests(unittest.TestCase):
    def test_management_apply_trust_is_main_only_and_scoped(self) -> None:
        source = (
            REPOSITORY_ROOT / "terraform/organization/foundation-apply.tf"
        ).read_text(encoding="utf-8")

        self.assertEqual(
            source.count(
                'oidc_subjects           = ["${local.foundation_ci_repository.subject_base}:ref:refs/heads/main"]'
            ),
            3,
        )
        self.assertNotIn(
            'oidc_subjects           = ["${local.foundation_ci_repository.subject_base}:pull_request"]',
            source,
        )
        self.assertIn("token.actions.githubusercontent.com:actor_id", source)
        self.assertIn("token.actions.githubusercontent.com:repository_id", source)
        self.assertIn("token.actions.githubusercontent.com:repository_owner_id", source)
        self.assertIn("token.actions.githubusercontent.com:workflow", source)
        self.assertIn('"Apply merged foundation configuration"', source)
        self.assertNotIn("token.actions.githubusercontent.com:workflow_ref", source)
        self.assertNotIn("token.actions.githubusercontent.com:job_workflow_ref", source)
        self.assertIn('management_state = "AWSFoundationManagementStateApply"', source)
        self.assertIn('organization     = "AWSFoundationOrganizationApply"', source)
        self.assertIn('platform         = "AWSFoundationPlatformApply"', source)
        self.assertNotIn("AdministratorAccess", source)
        self.assertNotIn('"s3:*"', source)
        self.assertNotIn('"iam:*"', source)
        self.assertNotIn('"organizations:*"', source)

    def test_apply_state_permissions_are_root_specific(self) -> None:
        source = (
            REPOSITORY_ROOT / "terraform/organization/foundation-apply.tf"
        ).read_text(encoding="utf-8")

        self.assertIn('"aws-foundation/platform/terraform.tfstate"', source)
        self.assertIn('"aws-foundation/organization/terraform.tfstate"', source)
        self.assertIn('"aws-foundation/management-state/terraform.tfstate"', source)
        self.assertNotIn("aws-foundation/github/terraform.tfstate", source)
        self.assertNotIn("joshcazalas-deployment-tfstate", source)

    def test_member_apply_roles_manage_control_plane_only(self) -> None:
        module_source = (
            REPOSITORY_ROOT
            / "terraform/modules/foundation-account-apply-role/main.tf"
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
    def test_direct_main_workflow_owns_apply_order(self) -> None:
        source = (
            REPOSITORY_ROOT / ".github/workflows/foundation-apply.yml"
        ).read_text(encoding="utf-8")

        self.assertIn("push:", source)
        self.assertIn("branches: [main]", source)
        self.assertNotIn("pull_request:", source)
        self.assertNotIn("workflow_dispatch:", source)
        self.assertIn("cancel-in-progress: false", source)
        self.assertIn("needs: apply-management-state", source)
        self.assertIn("needs: apply-organization", source)
        self.assertIn("AWSFoundationManagementStateApply", source)
        self.assertIn("AWSFoundationOrganizationApply", source)
        self.assertIn("AWSFoundationPlatformApply", source)
        self.assertEqual(source.count("id-token: write"), 3)
        self.assertNotIn("terraform/github", source)
        self.assertNotIn("actions: read", source)
        self.assertNotIn("pull-requests: read", source)
        self.assertNotIn("authorize-foundation-apply", source)
        self.assertNotIn("download-artifact", source)
        self.assertFalse(
            (
                REPOSITORY_ROOT
                / ".github/workflows/reusable-foundation-main-apply.yml"
            ).exists()
        )

    def test_apply_script_uses_automatic_apply_and_convergence_check(self) -> None:
        source = APPLY_SCRIPT.read_text(encoding="utf-8")

        self.assertIn("apply \\", source)
        self.assertIn("-auto-approve", source)
        self.assertIn("-lock-timeout=10m", source)
        self.assertIn("AWSFoundationTerraformApply", source)
        self.assertIn("Post-apply convergence failed", source)
        self.assertNotIn("-out=", source)
        self.assertNotIn("terraform/github", source)
        self.assertNotIn("REVIEWED_PLAN", source)
        self.assertNotIn("EXPECTED_CHANGES", source)


class FoundationApplyRunnerTests(unittest.TestCase):
    def run_apply(
        self, *, post_plan_exit_code: int = 0
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
    init|plan|apply)
      command_name="$argument"
      break
      ;;
  esac
done

case "$command_name" in
  init)
    printf 'init\n' >>"$FAKE_CALLS"
    ;;
  apply)
    printf 'apply\n' >>"$FAKE_CALLS"
    ;;
  plan)
    printf 'plan\n' >>"$FAKE_CALLS"
    exit "$FAKE_POST_PLAN_EXIT_CODE"
    ;;
  *)
    exit 64
    ;;
esac
""",
                encoding="utf-8",
            )
            fake_tofu.chmod(0o755)

            calls = temporary_path / "calls"
            calls.write_text("", encoding="utf-8")
            summary = temporary_path / "summary"
            environment = os.environ | {
                "FAKE_CALLS": str(calls),
                "FAKE_POST_PLAN_EXIT_CODE": str(post_plan_exit_code),
                "GITHUB_ACTOR": "joshcazalas",
                "GITHUB_SHA": "a" * 40,
                "GITHUB_STEP_SUMMARY": str(summary),
                "PATH": f"{fake_bin}:{os.environ['PATH']}",
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

    def test_apply_runs_once_and_proves_convergence(self) -> None:
        completed, calls, summary = self.run_apply()

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(calls, "init\napply\nplan\n")
        self.assertIn("Apply | Completed", summary)
        self.assertIn("Post-apply plan | No changes", summary)

    def test_nonconvergent_apply_fails(self) -> None:
        completed, calls, summary = self.run_apply(post_plan_exit_code=2)

        self.assertEqual(completed.returncode, 2)
        self.assertEqual(calls, "init\napply\nplan\n")
        self.assertEqual(summary, "")
        self.assertIn("Post-apply convergence failed", completed.stderr)


if __name__ == "__main__":
    unittest.main()
