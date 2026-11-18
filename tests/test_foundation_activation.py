from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path
from textwrap import dedent


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
TRUSTED_PLAN_WORKFLOW_SHA = "a5ef77db4d9c2d3d0eebc73170412105b0326bd5"


class FoundationWorkflowBoundaryTests(unittest.TestCase):
    def test_pr_checks_do_not_repeat_after_merge(self) -> None:
        source = (REPOSITORY_ROOT / ".github/workflows/pr.yml").read_text(
            encoding="utf-8"
        )

        triggers = source.split("permissions:", maxsplit=1)[0]
        self.assertIn("pull_request:", triggers)
        self.assertIn("workflow_dispatch:", triggers)
        self.assertNotIn("push:", triggers)

    def test_pull_request_planner_remains_pinned(self) -> None:
        source = (REPOSITORY_ROOT / ".github/workflows/pr.yml").read_text(
            encoding="utf-8"
        )

        self.assertIn(
            "reusable-foundation-plan.yml@" + TRUSTED_PLAN_WORKFLOW_SHA,
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
        self.assertIn("needs: [authorize, review]", plan)
        self.assertIn("needs.authorize.result == 'success'", plan)
        self.assertIn("github.event.pull_request.user.id == 49699333 && needs.review.result == 'success'", plan)
        self.assertIn("github.event.pull_request.user.id == 73436834 && needs.review.result == 'skipped'", plan)
        self.assertIn("id-token: write", plan)
        self.assertIn("job.workflow_sha", plan)
        self.assertIn("job.workflow_repository", plan)

    def test_dependabot_review_requires_josh_and_the_plan_environment_on_this_run(self) -> None:
        source = (REPOSITORY_ROOT / ".github/workflows/reusable-foundation-plan.yml").read_text()
        review = source.split("  review:\n", 1)[1].split("  plan:\n", 1)[0]
        self.assertIn("environment: dependabot-plan", review)
        self.assertIn("needs: authorize", review)
        self.assertNotIn("actions/checkout", review)
        self.assertNotIn("strategy:", review)
        verify = dedent(review.split("        run: |\n", 1)[1])
        mock_api = """
            gh() {
              [[ "$*" == "api repos/test/foundation/actions/runs/42/approvals" ]] || return 1
              cat
            }
            GITHUB_REPOSITORY=test/foundation
            GITHUB_RUN_ID=42
        """
        approval = {
            "state": "approved",
            "user": {"id": 73436834},
            "environments": [{"name": "dependabot-plan"}],
        }
        for reviews, allowed in [
            ([], False),
            ([approval], True),
            ([{**approval, "user": {"id": 1}}], False),
            ([{**approval, "environments": [{"name": "production"}]}], False),
            ([{**approval, "state": "rejected"}], False),
        ]:
            with self.subTest(reviews=reviews):
                result = subprocess.run(
                    ["bash", "-c", dedent(mock_api) + verify], input=json.dumps(reviews), text=True
                )
                self.assertEqual(result.returncode == 0, allowed)

    def test_required_check_handles_same_repository_and_fork_prs(self) -> None:
        source = (REPOSITORY_ROOT / ".github/workflows/pr.yml").read_text(
            encoding="utf-8"
        )

        required = source.split("  required:\n", maxsplit=1)[1]
        self.assertIn("name: Required pull request checks", required)
        self.assertIn("if: always()", required)
        self.assertIn("permissions: {}", required)
        self.assertIn("SOURCE_REPOSITORY", required)
        self.assertIn("TARGET_REPOSITORY", required)
        self.assertIn('"$PLAN_RESULT" != "success"', required)
        self.assertIn('"$PLAN_RESULT" != "skipped"', required)
        self.assertNotIn("actions/checkout", required)
        self.assertNotIn("id-token: write", required)
        self.assertNotIn("pull-requests: write", required)


if __name__ == "__main__":
    unittest.main()
