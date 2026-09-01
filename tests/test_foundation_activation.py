from __future__ import annotations

import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
TRUSTED_PLAN_WORKFLOW_SHA = "e2ac7f640c87bae963709a844c7e9adee610f098"


class FoundationWorkflowBoundaryTests(unittest.TestCase):
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
        self.assertIn("needs: authorize", plan)
        self.assertIn("id-token: write", plan)
        self.assertIn("job.workflow_sha", plan)
        self.assertIn("job.workflow_repository", plan)


if __name__ == "__main__":
    unittest.main()
