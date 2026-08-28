from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
RENDERER_PATH = REPOSITORY_ROOT / "scripts" / "render-plan-comment.py"
SPEC = importlib.util.spec_from_file_location("render_plan_comment", RENDERER_PATH)
assert SPEC is not None and SPEC.loader is not None
RENDERER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = RENDERER
SPEC.loader.exec_module(RENDERER)


class PlanSummaryTests(unittest.TestCase):
    def test_plan_json_is_partitioned_by_account_scope(self) -> None:
        plan = {
            "resource_changes": [
                {
                    "address": "module.foundation_plan_production.aws_iam_role.this",
                    "change": {"actions": ["create"]},
                },
                {
                    "address": "module.workloads_uat.aws_iam_role.this",
                    "change": {"actions": ["update"]},
                },
                {
                    "address": "aws_s3_bucket.deployment_state",
                    "change": {"actions": ["delete", "create"]},
                },
                {
                    "address": "data.aws_caller_identity.current",
                    "change": {"actions": ["read"]},
                },
                {
                    "address": "aws_s3_bucket.no_change",
                    "change": {"actions": ["no-op"]},
                },
            ]
        }
        completed = subprocess.run(
            [
                "jq",
                "--arg",
                "root",
                "terraform/platform",
                "-f",
                str(REPOSITORY_ROOT / "scripts" / "summarize-plan.jq"),
            ],
            input=json.dumps(plan),
            check=True,
            capture_output=True,
            text=True,
        )
        result = json.loads(completed.stdout)

        self.assertEqual([item["scope"] for item in result], ["production", "uat", "deployment"])
        self.assertEqual(result[2]["actions"], ["delete", "create"])

    def test_runner_writes_the_slugged_sanitized_artifact_layout(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary_path = Path(temporary_directory)
            source = temporary_path / "source"
            (source / "terraform" / "github").mkdir(parents=True)
            fake_bin = temporary_path / "bin"
            fake_bin.mkdir()
            fake_tofu = fake_bin / "tofu"
            fake_tofu.write_text(
                """#!/usr/bin/env bash
set -euo pipefail

command_name=""
for argument in "$@"; do
  case "$argument" in
    init|plan|show)
      command_name="$argument"
      break
      ;;
  esac
done

case "$command_name" in
  init)
    echo "Initialized."
    ;;
  plan)
    for argument in "$@"; do
      case "$argument" in
        -out=*)
          : >"${argument#-out=}"
          ;;
      esac
    done
    echo "No changes. Your infrastructure matches the configuration."
    ;;
  show)
    if [[ " $* " == *" -json "* ]]; then
      printf '{"resource_changes":[]}\\n'
    else
      echo "No changes. Your infrastructure matches the configuration."
    fi
    ;;
  *)
    exit 64
    ;;
esac
""",
                encoding="utf-8",
            )
            fake_tofu.chmod(0o755)
            results = temporary_path / "results"
            environment = os.environ.copy()
            environment["PATH"] = f"{fake_bin}:{environment['PATH']}"

            subprocess.run(
                [
                    "bash",
                    str(REPOSITORY_ROOT / "scripts" / "run-foundation-plan.sh"),
                    str(source),
                    "terraform/github",
                    str(results),
                ],
                check=True,
                capture_output=True,
                env=environment,
                text=True,
            )

            metadata_path = results / "github" / "metadata.json"
            plan_path = results / "github" / "plan.txt"
            self.assertTrue(metadata_path.is_file())
            self.assertTrue(plan_path.is_file())
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            self.assertEqual(metadata["status"], "success")
            self.assertEqual(
                metadata["scopes"],
                [{"name": "github", "add": 0, "change": 0, "destroy": 0}],
            )


class CommentRendererTests(unittest.TestCase):
    def write_result(
        self,
        directory: Path,
        root: str,
        slug: str,
        scopes: dict[str, tuple[int, int, int]],
        plan: str,
        status: str = "success",
    ) -> None:
        result_directory = directory / slug
        result_directory.mkdir()
        overall = tuple(sum(values[index] for values in scopes.values()) for index in range(3))
        metadata = {
            "root": root,
            "slug": slug,
            "status": status,
            "phase": "plan",
            "exit_code": 0 if overall == (0, 0, 0) else 2,
            "overall": {"add": overall[0], "change": overall[1], "destroy": overall[2]},
            "scopes": [
                {"name": name, "add": counts[0], "change": counts[1], "destroy": counts[2]}
                for name, counts in scopes.items()
            ],
        }
        (result_directory / "metadata.json").write_text(json.dumps(metadata), encoding="utf-8")
        (result_directory / "plan.txt").write_text(plan, encoding="utf-8")

    def complete_results(self, directory: Path, platform_plan: str = "No changes.") -> None:
        self.write_result(
            directory,
            "terraform/bootstrap/management-state",
            "management-state",
            {"management": (0, 0, 0)},
            "No changes.",
        )
        self.write_result(
            directory,
            "terraform/organization",
            "organization",
            {"management": (0, 0, 0)},
            "No changes.",
        )
        self.write_result(
            directory,
            "terraform/platform",
            "platform",
            {"production": (1, 0, 0), "uat": (0, 1, 0), "deployment": (0, 0, 1)},
            platform_plan,
        )
        self.write_result(
            directory,
            "terraform/github",
            "github",
            {"github": (0, 0, 0)},
            "No changes.",
        )

    def test_comment_is_ordered_colored_and_linked(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            results = Path(temporary_directory)
            self.complete_results(
                results,
                "+ aws_iam_role.new\n~ aws_iam_role.changed\n- aws_iam_role.old\n  neutral",
            )
            comment = RENDERER.render_comment(results, "owner/repository", "1234")

        self.assertTrue(comment.startswith(RENDERER.MARKER))
        self.assertLess(comment.index("### Production"), comment.index("### UAT"))
        self.assertLess(comment.index("### UAT"), comment.index("### Deployment"))
        self.assertLess(comment.index("### Deployment"), comment.index("### Management"))
        self.assertIn("| GitHub | No changes. Your infrastructure matches the configuration. |\n\n### Production", comment)
        self.assertIn("</details>\n\n### UAT", comment)
        self.assertIn("</details>\n\n### Deployment", comment)
        self.assertIn("</details>\n\n### Management", comment)
        self.assertIn("</details>\n\n### GitHub", comment)
        self.assertIn("| Production | 1 to add, 0 to change, 0 to destroy. |", comment)
        self.assertIn("+ + aws_iam_role.new", comment)
        self.assertIn("! ! aws_iam_role.changed", comment)
        self.assertIn("- - aws_iam_role.old", comment)
        self.assertNotIn("This root spans three AWS accounts", comment)
        self.assertIn("[View CI run](https://github.com/owner/repository/actions/runs/1234)", comment)

    def test_missing_artifact_is_reported_as_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            results = Path(temporary_directory)
            self.complete_results(results)
            for path in (results / "github").iterdir():
                path.unlink()
            (results / "github").rmdir()
            comment = RENDERER.render_comment(results, "owner/repository", "1234")

        self.assertIn("| GitHub | Plan failed. Review the CI run. |", comment)
        self.assertIn("The plan result artifact is missing.", comment)

    def test_large_plan_is_deterministically_truncated(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            results = Path(temporary_directory)
            self.complete_results(results, "+ resource change\n" * 10_000)
            first = RENDERER.render_comment(results, "owner/repository", "1234")
            second = RENDERER.render_comment(results, "owner/repository", "1234")

        self.assertEqual(first, second)
        self.assertLessEqual(len(first), RENDERER.MAX_COMMENT_LENGTH)
        self.assertIn(RENDERER.TRUNCATION_MESSAGE, first)
        for _, label in RENDERER.SCOPES:
            self.assertIn(f"### {label}", first)


if __name__ == "__main__":
    unittest.main()
