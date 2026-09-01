from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
GOVERNANCE_ROOT = REPOSITORY_ROOT / ".github/governance"
WORKFLOW_ROOT = REPOSITORY_ROOT / ".github/workflows"
FULL_SHA = re.compile(r"^[0-9a-f]{40}$")


def load_payload(name: str) -> dict[str, object]:
    return json.loads((GOVERNANCE_ROOT / name).read_text(encoding="utf-8"))


class RepositoryGovernanceTests(unittest.TestCase):
    def test_main_ruleset_has_no_bypass_and_protects_main(self) -> None:
        payload = load_payload("main-ruleset.json")

        self.assertEqual(payload["enforcement"], "active")
        self.assertEqual(payload["bypass_actors"], [])
        self.assertEqual(
            payload["conditions"],
            {
                "ref_name": {
                    "include": ["refs/heads/main"],
                    "exclude": [],
                }
            },
        )

        rules = {rule["type"]: rule for rule in payload["rules"]}
        self.assertIn("deletion", rules)
        self.assertIn("non_fast_forward", rules)

        pull_requests = rules["pull_request"]["parameters"]
        self.assertEqual(pull_requests["allowed_merge_methods"], ["merge"])
        self.assertEqual(pull_requests["required_approving_review_count"], 0)
        self.assertTrue(pull_requests["required_review_thread_resolution"])

        checks = rules["required_status_checks"]["parameters"]
        self.assertFalse(checks["strict_required_status_checks_policy"])
        self.assertEqual(
            checks["required_status_checks"],
            [
                {
                    "context": "Required pull request checks",
                    "integration_id": 15368,
                }
            ],
        )

    def test_actions_policy_is_an_explicit_full_sha_allowlist(self) -> None:
        permissions = load_payload("actions-permissions.json")
        selected = load_payload("selected-actions.json")

        self.assertEqual(permissions["allowed_actions"], "selected")
        self.assertTrue(permissions["sha_pinning_required"])
        self.assertTrue(selected["github_owned_allowed"])
        self.assertFalse(selected["verified_allowed"])
        self.assertEqual(
            set(selected["patterns_allowed"]),
            {
                "aws-actions/configure-aws-credentials@*",
                "joshcazalas/aws-foundation@*",
                "opentofu/setup-opentofu@*",
                "terraform-linters/setup-tflint@*",
            },
        )

    def test_every_remote_action_reference_uses_a_full_sha(self) -> None:
        for workflow in WORKFLOW_ROOT.glob("*.yml"):
            source = workflow.read_text(encoding="utf-8")
            for reference in re.findall(r"^\s*uses:\s*([^\s#]+)", source, re.M):
                if reference.startswith("./"):
                    continue
                self.assertIn("@", reference, f"{workflow}: {reference}")
                revision = reference.rsplit("@", maxsplit=1)[1]
                self.assertRegex(revision, FULL_SHA, f"{workflow}: {reference}")

    def test_fork_policy_requires_approval_from_every_external_contributor(self) -> None:
        self.assertEqual(
            load_payload("fork-approval.json"),
            {"approval_policy": "all_external_contributors"},
        )

    def test_default_workflow_token_cannot_approve_reviews(self) -> None:
        self.assertEqual(
            load_payload("workflow-permissions.json"),
            {
                "default_workflow_permissions": "read",
                "can_approve_pull_request_reviews": False,
            },
        )

    def test_native_secret_protection_is_enabled(self) -> None:
        self.assertEqual(
            load_payload("security-and-analysis.json"),
            {
                "security_and_analysis": {
                    "secret_scanning": {"status": "enabled"},
                    "secret_scanning_push_protection": {"status": "enabled"},
                }
            },
        )

    def test_no_workflow_uses_pull_request_target(self) -> None:
        for workflow in WORKFLOW_ROOT.glob("*.yml"):
            source = workflow.read_text(encoding="utf-8")
            self.assertNotIn("pull_request_target", source, str(workflow))

    def test_no_workflow_can_merge_a_pull_request(self) -> None:
        forbidden = ("gh pr merge", "merge_pull_request", "enable-auto-merge")
        for workflow in WORKFLOW_ROOT.glob("*.yml"):
            source = workflow.read_text(encoding="utf-8")
            for marker in forbidden:
                self.assertNotIn(marker, source, str(workflow))

    def test_repository_settings_match_reviewed_merge_policy(self) -> None:
        settings = load_payload("repository-settings.json")

        self.assertEqual(settings["visibility"], "public")
        self.assertTrue(settings["allow_merge_commit"])
        self.assertFalse(settings["allow_squash_merge"])
        self.assertFalse(settings["allow_rebase_merge"])
        self.assertTrue(settings["delete_branch_on_merge"])


if __name__ == "__main__":
    unittest.main()
