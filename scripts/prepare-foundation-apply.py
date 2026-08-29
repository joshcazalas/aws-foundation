#!/usr/bin/env python3
"""Validate reviewed plan metadata and expose bounded apply inputs."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


ROOTS = {
    "management-state": (
        "terraform/bootstrap/management-state",
        ("management",),
    ),
    "organization": ("terraform/organization", ("management",)),
    "platform": ("terraform/platform", ("production", "uat", "deployment")),
    "github": ("terraform/github", ("github",)),
}
ACTION_SEQUENCES = {
    ("create",),
    ("update",),
    ("delete",),
    ("create", "delete"),
    ("delete", "create"),
}
DIGEST_PATTERN = re.compile(r"^[a-f0-9]{64}$")


def fail(message: str) -> None:
    raise ValueError(message)


def integer(value: Any, field: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        fail(f"{field} must be a non-negative integer")
    return value


def validate_counts(value: Any, field: str) -> dict[str, int]:
    if not isinstance(value, dict):
        fail(f"{field} must be an object")
    if set(value) != {"add", "change", "destroy"}:
        fail(f"{field} has unexpected count fields")
    return {name: integer(value[name], f"{field}.{name}") for name in value}


def load_root(results_directory: Path, slug: str) -> tuple[list[dict[str, Any]], str]:
    expected_root, expected_scopes = ROOTS[slug]
    root_directory = results_directory / slug
    metadata_path = root_directory / "metadata.json"
    plan_path = root_directory / "plan.txt"

    if not root_directory.is_dir() or root_directory.is_symlink():
        fail(f"the {slug} artifact directory is missing or unsafe")
    if {path.name for path in root_directory.iterdir()} != {"metadata.json", "plan.txt"}:
        fail(f"the {slug} artifact has an unexpected file layout")
    if not metadata_path.is_file() or metadata_path.is_symlink():
        fail(f"the {slug} metadata file is missing or unsafe")
    if not plan_path.is_file() or plan_path.is_symlink():
        fail(f"the {slug} redacted plan file is missing or unsafe")

    try:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        fail(f"the {slug} metadata is not valid JSON: {error}")

    if not isinstance(metadata, dict):
        fail(f"the {slug} metadata must be an object")
    if metadata.get("root") != expected_root or metadata.get("slug") != slug:
        fail(f"the {slug} artifact identity is invalid")
    if metadata.get("status") != "success" or metadata.get("phase") != "plan":
        fail(f"the {slug} artifact is not a successful plan")

    digest = metadata.get("plan_digest")
    if not isinstance(digest, str) or not DIGEST_PATTERN.fullmatch(digest):
        fail(f"the {slug} plan digest is invalid")

    changes = metadata.get("changes")
    if not isinstance(changes, list):
        fail(f"the {slug} changes must be an array")

    validated_changes: list[dict[str, Any]] = []
    addresses: set[str] = set()
    for index, change in enumerate(changes):
        if not isinstance(change, dict) or set(change) != {"address", "actions", "scope"}:
            fail(f"the {slug} change at index {index} has an invalid shape")
        address = change["address"]
        actions = change["actions"]
        scope = change["scope"]
        if not isinstance(address, str) or not address or "\n" in address or "\r" in address:
            fail(f"the {slug} change at index {index} has an invalid address")
        if address in addresses:
            fail(f"the {slug} change manifest contains a duplicate address")
        if not isinstance(actions, list) or tuple(actions) not in ACTION_SEQUENCES:
            fail(f"the {slug} change at index {index} has invalid actions")
        if scope not in expected_scopes:
            fail(f"the {slug} change at index {index} has an invalid scope")
        addresses.add(address)
        validated_changes.append({"address": address, "actions": actions, "scope": scope})

    if validated_changes != sorted(validated_changes, key=lambda item: item["address"]):
        fail(f"the {slug} change manifest is not canonically ordered")

    expected_exit_code = 0 if not validated_changes else 2
    if metadata.get("exit_code") != expected_exit_code:
        fail(f"the {slug} detailed exit code disagrees with its changes")

    overall = validate_counts(metadata.get("overall"), f"{slug}.overall")
    expected_overall = {
        "add": sum("create" in item["actions"] for item in validated_changes),
        "change": sum("update" in item["actions"] for item in validated_changes),
        "destroy": sum("delete" in item["actions"] for item in validated_changes),
    }
    if overall != expected_overall:
        fail(f"the {slug} overall counts disagree with its changes")

    scopes = metadata.get("scopes")
    if not isinstance(scopes, list) or len(scopes) != len(expected_scopes):
        fail(f"the {slug} scopes are invalid")
    scope_names: list[str] = []
    for index, scope_result in enumerate(scopes):
        if not isinstance(scope_result, dict) or set(scope_result) != {
            "name",
            "add",
            "change",
            "destroy",
        }:
            fail(f"the {slug} scope at index {index} has an invalid shape")
        name = scope_result["name"]
        if name not in expected_scopes:
            fail(f"the {slug} scope at index {index} is unexpected")
        scope_names.append(name)
        actual = validate_counts(
            {key: scope_result[key] for key in ("add", "change", "destroy")},
            f"{slug}.scopes[{index}]",
        )
        expected = {
            "add": sum(
                item["scope"] == name and "create" in item["actions"]
                for item in validated_changes
            ),
            "change": sum(
                item["scope"] == name and "update" in item["actions"]
                for item in validated_changes
            ),
            "destroy": sum(
                item["scope"] == name and "delete" in item["actions"]
                for item in validated_changes
            ),
        }
        if actual != expected:
            fail(f"the {slug} scope counts disagree with its changes")
    if tuple(scope_names) != expected_scopes:
        fail(f"the {slug} scopes are not canonically ordered")

    return validated_changes, digest


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} RESULTS_DIRECTORY GITHUB_OUTPUT", file=sys.stderr)
        return 64

    results_directory = Path(sys.argv[1]).resolve()
    output_path = Path(sys.argv[2])
    if not results_directory.is_dir():
        print("The reviewed plan result directory does not exist.", file=sys.stderr)
        return 66

    try:
        if {path.name for path in results_directory.iterdir()} != set(ROOTS):
            fail("the reviewed plan directory has an unexpected artifact layout")
        results = {slug: load_root(results_directory, slug) for slug in ROOTS}
    except ValueError as error:
        print(f"Reviewed plan validation failed: {error}", file=sys.stderr)
        return 1

    with output_path.open("a", encoding="utf-8") as output:
        for slug in ("management-state", "organization", "platform"):
            changes, digest = results[slug]
            key = slug.replace("-", "_")
            output.write(
                f"{key}_changes={json.dumps(changes, separators=(',', ':'), sort_keys=True)}\n"
            )
            output.write(f"{key}_digest={digest}\n")

    summary = ", ".join(
        f"{slug}={len(changes)}" for slug, (changes, _) in results.items()
    )
    print(f"Validated exact reviewed plan metadata ({summary}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
