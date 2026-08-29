from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
PREPARE_SCRIPT = REPOSITORY_ROOT / "scripts" / "prepare-foundation-apply.py"
TRUSTED_WORKFLOW_SHA = "e2ac7f640c87bae963709a844c7e9adee610f098"

ROOTS = {
    "management-state": (
        "terraform/bootstrap/management-state",
        ("management",),
    ),
    "organization": ("terraform/organization", ("management",)),
    "platform": ("terraform/platform", ("production", "uat", "deployment")),
    "github": ("terraform/github", ("github",)),
}


class FoundationActivationWorkflowTests(unittest.TestCase):
    def test_caller_is_a_minimal_main_push_pinned_to_the_control_plane(self) -> None:
        source = (
            REPOSITORY_ROOT / ".github/workflows/foundation-apply.yml"
        ).read_text(encoding="utf-8")

        self.assertIn("push:", source)
        self.assertIn("branches: [main]", source)
        self.assertNotIn("pull_request:", source)
        self.assertNotIn("workflow_dispatch:", source)
        self.assertIn(
            "reusable-foundation-main-apply.yml@" + TRUSTED_WORKFLOW_SHA,
            source,
        )
        self.assertIn("actions: read", source)
        self.assertIn("contents: read", source)
        self.assertIn("id-token: write", source)
        self.assertIn("pull-requests: read", source)
        self.assertIn("secrets: inherit", source)
        self.assertNotIn("github.event.pull_request", source)
        self.assertNotIn("reviewed_plan", source)
        self.assertNotIn("terraform/", source)

    def test_pull_request_planner_is_pinned_to_the_same_control_plane(self) -> None:
        source = (REPOSITORY_ROOT / ".github/workflows/pr.yml").read_text(
            encoding="utf-8"
        )

        self.assertIn(
            "reusable-foundation-plan.yml@" + TRUSTED_WORKFLOW_SHA,
            source,
        )
        self.assertNotIn("reusable-foundation-plan.yml@main", source)

    def test_reusable_plan_authorizes_before_receiving_oidc(self) -> None:
        source = (
            REPOSITORY_ROOT / ".github/workflows/reusable-foundation-plan.yml"
        ).read_text(encoding="utf-8")

        authorize, plan = source.split("  plan:\n", maxsplit=1)
        self.assertIn("permissions: {}", authorize)
        self.assertNotIn("id-token: write", authorize)
        self.assertIn("Fork pull requests receive static validation only", authorize)
        self.assertIn("github.event.pull_request.head.repo.id", authorize)
        self.assertIn("github.actor_id", authorize)
        self.assertIn("github.triggering_actor", authorize)
        self.assertIn("needs: authorize", plan)
        self.assertIn("id-token: write", plan)
        self.assertIn("job.workflow_sha", plan)
        self.assertIn("job.workflow_repository", plan)


class ReviewedPlanMetadataTests(unittest.TestCase):
    def write_results(
        self,
        parent: Path,
        overrides: dict[str, dict[str, object]] | None = None,
    ) -> None:
        overrides = overrides or {}
        for slug, (root, scopes) in ROOTS.items():
            result_directory = parent / slug
            result_directory.mkdir(parents=True)
            changes: list[dict[str, object]] = []
            if slug == "platform":
                changes = [
                    {
                        "address": "module.workloads_uat.aws_iam_role.example",
                        "actions": ["update"],
                        "scope": "uat",
                    }
                ]
            overall = {
                "add": sum("create" in item["actions"] for item in changes),
                "change": sum("update" in item["actions"] for item in changes),
                "destroy": sum("delete" in item["actions"] for item in changes),
            }
            scope_results = []
            for scope in scopes:
                selected = [item for item in changes if item["scope"] == scope]
                scope_results.append(
                    {
                        "name": scope,
                        "add": sum("create" in item["actions"] for item in selected),
                        "change": sum("update" in item["actions"] for item in selected),
                        "destroy": sum("delete" in item["actions"] for item in selected),
                    }
                )
            metadata: dict[str, object] = {
                "root": root,
                "slug": slug,
                "status": "success",
                "phase": "plan",
                "plan_digest": "a" * 64,
                "exit_code": 2 if changes else 0,
                "overall": overall,
                "scopes": scope_results,
                "changes": changes,
            }
            metadata.update(overrides.get(slug, {}))
            (result_directory / "metadata.json").write_text(
                json.dumps(metadata), encoding="utf-8"
            )
            (result_directory / "plan.txt").write_text(
                "Sanitized plan text.\n", encoding="utf-8"
            )

    def run_prepare(
        self, overrides: dict[str, dict[str, object]] | None = None
    ) -> tuple[subprocess.CompletedProcess[str], str]:
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary_path = Path(temporary_directory)
            results = temporary_path / "results"
            results.mkdir()
            self.write_results(results, overrides)
            output = temporary_path / "github-output"
            output.write_text("", encoding="utf-8")
            completed = subprocess.run(
                ["python3", str(PREPARE_SCRIPT), str(results), str(output)],
                check=False,
                capture_output=True,
                text=True,
            )
            return completed, output.read_text(encoding="utf-8")

    def test_valid_metadata_emits_only_automatic_root_inputs(self) -> None:
        completed, output = self.run_prepare()

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn("management_state_changes=[]", output)
        self.assertIn("organization_changes=[]", output)
        self.assertIn(
            'platform_changes=[{"actions":["update"],'
            '"address":"module.workloads_uat.aws_iam_role.example","scope":"uat"}]',
            output,
        )
        self.assertIn("platform_digest=" + "a" * 64, output)
        self.assertNotIn("github_changes", output)

    def test_count_mismatch_fails_closed(self) -> None:
        completed, output = self.run_prepare(
            {"platform": {"overall": {"add": 0, "change": 0, "destroy": 0}}}
        )

        self.assertNotEqual(completed.returncode, 0)
        self.assertEqual(output, "")
        self.assertIn("overall counts disagree", completed.stderr)

    def test_invalid_digest_fails_closed(self) -> None:
        completed, output = self.run_prepare(
            {"organization": {"plan_digest": "not-a-digest"}}
        )

        self.assertNotEqual(completed.returncode, 0)
        self.assertEqual(output, "")
        self.assertIn("plan digest is invalid", completed.stderr)

    def test_unexpected_artifact_file_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary_path = Path(temporary_directory)
            results = temporary_path / "results"
            results.mkdir()
            self.write_results(results)
            (results / "organization" / "raw-plan.json").write_text(
                "{}", encoding="utf-8"
            )
            output = temporary_path / "github-output"
            output.write_text("", encoding="utf-8")

            completed = subprocess.run(
                ["python3", str(PREPARE_SCRIPT), str(results), str(output)],
                check=False,
                capture_output=True,
                text=True,
            )

            self.assertNotEqual(completed.returncode, 0)
            self.assertEqual(output.read_text(encoding="utf-8"), "")
            self.assertIn("unexpected file layout", completed.stderr)


if __name__ == "__main__":
    unittest.main()
