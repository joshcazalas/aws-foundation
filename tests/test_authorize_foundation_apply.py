from __future__ import annotations

import copy
import importlib.util
import unittest
from pathlib import Path
from typing import Any


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPOSITORY_ROOT / "scripts" / "authorize-foundation-apply.py"
SPEC = importlib.util.spec_from_file_location("authorize_foundation_apply", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


TRUSTED_SHA = "a" * 40
MAIN_SHA = "b" * 40
HEAD_SHA = "c" * 40
RUN_ID = "9001"
PLAN_RUN_ID = 8001
PULL_REQUEST_NUMBER = 42


def repository() -> dict[str, Any]:
    return {
        "id": 1346584597,
        "full_name": "joshcazalas/aws-foundation",
        "owner": {"id": 73436834},
    }


def user() -> dict[str, Any]:
    return {"id": 73436834, "login": "joshcazalas", "type": "User"}


def environment() -> dict[str, str]:
    return {
        "GITHUB_ACTOR_ID": "73436834",
        "GITHUB_EVENT_NAME": "push",
        "GITHUB_REF": "refs/heads/main",
        "GITHUB_REPOSITORY": "joshcazalas/aws-foundation",
        "GITHUB_REPOSITORY_ID": "1346584597",
        "GITHUB_REPOSITORY_OWNER_ID": "73436834",
        "GITHUB_RUN_ID": RUN_ID,
        "GITHUB_SHA": MAIN_SHA,
        "GITHUB_WORKFLOW_REF": (
            "joshcazalas/aws-foundation/.github/workflows/"
            "foundation-apply.yml@refs/heads/main"
        ),
        "TRUSTED_WORKFLOW_SHA": TRUSTED_SHA,
    }


def push_event() -> dict[str, Any]:
    return {
        "after": MAIN_SHA,
        "before": "d" * 40,
        "deleted": False,
        "forced": False,
        "head_commit": {"id": MAIN_SHA},
        "ref": "refs/heads/main",
        "repository": repository(),
        "sender": user(),
    }


def pull_request() -> dict[str, Any]:
    return {
        "base": {"ref": "main", "repo": repository()},
        "head": {"ref": "feature", "repo": repository(), "sha": HEAD_SHA},
        "merge_commit_sha": MAIN_SHA,
        "merged": True,
        "merged_at": "2026-08-29T12:00:00Z",
        "merged_by": user(),
        "number": PULL_REQUEST_NUMBER,
        "state": "closed",
    }


def current_run() -> dict[str, Any]:
    return {
        "actor": user(),
        "created_at": "2026-08-29T12:05:00Z",
        "event": "push",
        "head_branch": "main",
        "head_sha": MAIN_SHA,
        "id": int(RUN_ID),
        "name": "Apply merged foundation configuration",
        "path": ".github/workflows/foundation-apply.yml",
        "referenced_workflows": [
            {
                "path": (
                    "joshcazalas/aws-foundation/.github/workflows/"
                    f"reusable-foundation-main-apply.yml@{TRUSTED_SHA}"
                ),
                "ref": TRUSTED_SHA,
                "sha": TRUSTED_SHA,
            }
        ],
        "repository": repository(),
        "triggering_actor": user(),
    }


def plan_run() -> dict[str, Any]:
    abbreviated_repo = {"id": 1346584597, "name": "aws-foundation"}
    return {
        "actor": user(),
        "conclusion": "success",
        "event": "pull_request",
        "head_sha": HEAD_SHA,
        "id": PLAN_RUN_ID,
        "name": "Pull request checks",
        "path": ".github/workflows/pr.yml",
        "pull_requests": [
            {
                "base": {"ref": "main", "repo": abbreviated_repo},
                "head": {"ref": "feature", "repo": abbreviated_repo, "sha": HEAD_SHA},
                "number": PULL_REQUEST_NUMBER,
            }
        ],
        "referenced_workflows": [
            {
                "path": (
                    "joshcazalas/aws-foundation/.github/workflows/"
                    f"reusable-foundation-plan.yml@{TRUSTED_SHA}"
                ),
                "ref": TRUSTED_SHA,
                "sha": TRUSTED_SHA,
            }
        ],
        "repository": repository(),
        "status": "completed",
        "triggering_actor": user(),
        "updated_at": "2026-08-29T11:59:00Z",
        "workflow_id": 344385929,
    }


def comments() -> list[dict[str, Any]]:
    return [
        {
            "body": (
                "<!-- aws-foundation-terraform-plan -->\n"
                "Reviewed plan: https://github.com/joshcazalas/"
                f"aws-foundation/actions/runs/{PLAN_RUN_ID}"
            ),
            "updated_at": "2026-08-29T11:59:30Z",
            "user": {
                "id": 41898282,
                "login": "github-actions[bot]",
                "type": "Bot",
            },
        }
    ]


def artifacts() -> dict[str, Any]:
    names = {
        "foundation-plan-github",
        "foundation-plan-management-state",
        "foundation-plan-organization",
        "foundation-plan-platform",
    }
    return {
        "artifacts": [
            {
                "expired": False,
                "name": name,
                "workflow_run": {
                    "head_repository_id": 1346584597,
                    "head_sha": HEAD_SHA,
                    "id": PLAN_RUN_ID,
                    "repository_id": 1346584597,
                },
            }
            for name in sorted(names)
        ],
        "total_count": 4,
    }


class FakeAPI:
    def __init__(self) -> None:
        self.pr = pull_request()
        self.current = current_run()
        self.plan = plan_run()
        self.comment_values = comments()
        self.artifact_values = artifacts()
        self.associated: list[dict[str, Any]] = [{"number": PULL_REQUEST_NUMBER}]

    def get(self, path: str) -> Any:
        values = {
            f"repos/joshcazalas/aws-foundation/actions/runs/{RUN_ID}": self.current,
            f"repos/joshcazalas/aws-foundation/commits/{MAIN_SHA}/pulls": self.associated,
            f"repos/joshcazalas/aws-foundation/pulls/{PULL_REQUEST_NUMBER}": self.pr,
            f"repos/joshcazalas/aws-foundation/actions/runs/{PLAN_RUN_ID}": self.plan,
            (
                "repos/joshcazalas/aws-foundation/actions/runs/"
                f"{PLAN_RUN_ID}/artifacts?per_page=100"
            ): self.artifact_values,
        }
        return copy.deepcopy(values[path])

    def get_all(self, path: str) -> list[Any]:
        expected = (
            "repos/joshcazalas/aws-foundation/issues/"
            f"{PULL_REQUEST_NUMBER}/comments"
        )
        if path != expected:
            raise KeyError(path)
        return copy.deepcopy(self.comment_values)


class FoundationApplyAuthorizationTests(unittest.TestCase):
    def authorize(self, api: FakeAPI) -> dict[str, str]:
        return MODULE.authorize(api, environment(), push_event(), sleeper=lambda _: None)

    def test_accepts_exact_merged_pull_request_and_reviewed_plan(self) -> None:
        result = self.authorize(FakeAPI())

        self.assertEqual(result["pull_request_number"], str(PULL_REQUEST_NUMBER))
        self.assertEqual(result["plan_run_id"], str(PLAN_RUN_ID))
        self.assertEqual(result["trusted_workflow_sha"], TRUSTED_SHA)

    def test_rejects_direct_push_without_associated_merge(self) -> None:
        api = FakeAPI()
        api.associated = []

        with self.assertRaisesRegex(
            MODULE.AuthorizationError, "exactly one fresh merged pull request"
        ):
            self.authorize(api)

    def test_rejects_fork_pull_request(self) -> None:
        api = FakeAPI()
        api.pr["head"]["repo"] = {
            "id": 999,
            "full_name": "attacker/aws-foundation",
            "owner": {"id": 999},
        }

        with self.assertRaisesRegex(
            MODULE.AuthorizationError, "exactly one fresh merged pull request"
        ):
            self.authorize(api)

    def test_rejects_rerun_by_another_actor(self) -> None:
        api = FakeAPI()
        api.current["triggering_actor"] = {
            "id": 999,
            "login": "attacker",
            "type": "User",
        }

        with self.assertRaisesRegex(MODULE.AuthorizationError, "triggering actor"):
            self.authorize(api)

    def test_rejects_unpinned_plan_workflow(self) -> None:
        api = FakeAPI()
        api.plan["referenced_workflows"][0]["path"] = (
            "joshcazalas/aws-foundation/.github/workflows/"
            "reusable-foundation-plan.yml@main"
        )

        with self.assertRaisesRegex(MODULE.AuthorizationError, "not pinned"):
            self.authorize(api)


if __name__ == "__main__":
    unittest.main()
