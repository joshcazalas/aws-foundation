#!/usr/bin/env python3
"""Authorize a main-branch foundation apply from immutable GitHub evidence."""

from __future__ import annotations

import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Callable, Mapping, Protocol


EXPECTED_REPOSITORY = "joshcazalas/aws-foundation"
EXPECTED_REPOSITORY_ID = 1346584597
EXPECTED_OWNER_ID = 73436834
EXPECTED_ACTOR_ID = 73436834
EXPECTED_BOT_ID = 41898282
EXPECTED_CALLER_NAME = "Apply merged foundation configuration"
EXPECTED_CALLER_PATH = ".github/workflows/foundation-apply.yml"
EXPECTED_PLAN_NAME = "Pull request checks"
EXPECTED_PLAN_PATH = ".github/workflows/pr.yml"
EXPECTED_PLAN_WORKFLOW_ID = 344385929
EXPECTED_ARTIFACT_NAMES = {
    "foundation-plan-github",
    "foundation-plan-management-state",
    "foundation-plan-organization",
    "foundation-plan-platform",
}
STICKY_COMMENT_MARKER = "<!-- aws-foundation-terraform-plan -->"
RUN_LINK = re.compile(
    r"https://github[.]com/joshcazalas/aws-foundation/actions/runs/([1-9][0-9]*)"
)
SHA = re.compile(r"^[a-f0-9]{40}$")
MAX_MERGE_TO_RUN_DELAY = timedelta(hours=1)


class AuthorizationError(ValueError):
    """Raised when GitHub evidence does not satisfy the apply contract."""


class API(Protocol):
    def get(self, path: str) -> Any: ...

    def get_all(self, path: str) -> list[Any]: ...


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AuthorizationError(message)


def object_value(value: Any, name: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{name} must be an object")
    return value


def list_value(value: Any, name: str) -> list[Any]:
    require(isinstance(value, list), f"{name} must be an array")
    return value


def integer(value: Any, name: str) -> int:
    require(isinstance(value, int) and not isinstance(value, bool), f"{name} is invalid")
    return value


def timestamp(value: Any, name: str) -> datetime:
    require(isinstance(value, str), f"{name} is invalid")
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise AuthorizationError(f"{name} is invalid") from error
    require(result.tzinfo is not None, f"{name} must include a timezone")
    return result.astimezone(timezone.utc)


def exact_user(value: Any, expected_id: int, expected_login: str, name: str) -> None:
    user = object_value(value, name)
    require(integer(user.get("id"), f"{name}.id") == expected_id, f"{name} ID mismatch")
    require(user.get("login") == expected_login, f"{name} login mismatch")


class GitHubAPI:
    def __init__(self, base_url: str, token: str) -> None:
        self.base_url = base_url.rstrip("/")
        self.headers = {
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "aws-foundation-apply-authorizer",
            "X-GitHub-Api-Version": "2022-11-28",
        }

    def _request(self, url: str) -> tuple[Any, Mapping[str, str]]:
        request = urllib.request.Request(url, headers=self.headers)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response), response.headers
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as error:
            raise AuthorizationError(f"GitHub API request failed: {error}") from error

    def get(self, path: str) -> Any:
        value, _ = self._request(f"{self.base_url}/{path.lstrip('/')}")
        return value

    def get_all(self, path: str) -> list[Any]:
        separator = "&" if "?" in path else "?"
        url: str | None = f"{self.base_url}/{path.lstrip('/')}{separator}per_page=100"
        values: list[Any] = []
        pages = 0
        while url is not None:
            pages += 1
            require(pages <= 20, "GitHub API pagination exceeded its safety bound")
            page, headers = self._request(url)
            values.extend(list_value(page, "paginated GitHub response"))
            url = None
            for part in headers.get("Link", "").split(","):
                if 'rel="next"' not in part:
                    continue
                match = re.search(r"<([^>]+)>", part)
                require(match is not None, "GitHub API returned an invalid pagination link")
                url = match.group(1)
                break
        return values


def validate_repository(repository: Any, name: str) -> None:
    value = object_value(repository, name)
    require(integer(value.get("id"), f"{name}.id") == EXPECTED_REPOSITORY_ID, f"{name} ID mismatch")
    require(value.get("full_name") == EXPECTED_REPOSITORY, f"{name} name mismatch")
    owner = object_value(value.get("owner"), f"{name}.owner")
    require(integer(owner.get("id"), f"{name}.owner.id") == EXPECTED_OWNER_ID, f"{name} owner mismatch")


def eligible_pull_request(pr: Any, sha: str, run_created_at: datetime) -> bool:
    try:
        value = object_value(pr, "pull request")
        require(value.get("state") == "closed", "pull request is not closed")
        require(value.get("merged") is True, "pull request is not merged")
        require(value.get("merge_commit_sha") == sha, "pull request merge SHA mismatch")
        require(integer(value.get("number"), "pull request number") > 0, "pull request number is invalid")

        base = object_value(value.get("base"), "pull request base")
        require(base.get("ref") == "main", "pull request base is not main")
        validate_repository(base.get("repo"), "pull request base repository")

        head = object_value(value.get("head"), "pull request head")
        require(isinstance(head.get("sha"), str) and SHA.fullmatch(head["sha"]) is not None, "pull request head SHA is invalid")
        validate_repository(head.get("repo"), "pull request head repository")

        exact_user(value.get("merged_by"), EXPECTED_ACTOR_ID, "joshcazalas", "pull request merger")
        merged_at = timestamp(value.get("merged_at"), "pull request merged_at")
        require(merged_at <= run_created_at, "pull request was merged after the apply run started")
        require(run_created_at - merged_at <= MAX_MERGE_TO_RUN_DELAY, "pull request merge is not fresh for this push run")
        return True
    except AuthorizationError:
        return False


def find_merged_pull_request(
    api: API,
    sha: str,
    run_created_at: datetime,
    sleeper: Callable[[float], None],
) -> dict[str, Any]:
    eligible: list[dict[str, Any]] = []
    for attempt, delay in enumerate((0, 2, 5, 10)):
        if delay:
            sleeper(delay)
        candidates = list_value(
            api.get(f"repos/{EXPECTED_REPOSITORY}/commits/{sha}/pulls"),
            "associated pull requests",
        )
        eligible = []
        for candidate in candidates:
            summary = object_value(candidate, "associated pull request")
            number = integer(summary.get("number"), "associated pull request number")
            full = api.get(f"repos/{EXPECTED_REPOSITORY}/pulls/{number}")
            if eligible_pull_request(full, sha, run_created_at):
                eligible.append(object_value(full, "eligible pull request"))
        if len(eligible) == 1:
            return eligible[0]
        if len(eligible) > 1 or attempt == 3:
            break
    require(len(eligible) == 1, "expected exactly one fresh merged pull request for the pushed main SHA")
    raise AssertionError("unreachable")


def validate_run_repository(value: Any, name: str) -> None:
    repository = object_value(value, name)
    require(integer(repository.get("id"), f"{name}.id") == EXPECTED_REPOSITORY_ID, f"{name} ID mismatch")
    require(repository.get("full_name") == EXPECTED_REPOSITORY, f"{name} name mismatch")


def validate_current_run(run: Any, env: Mapping[str, str], trusted_sha: str) -> datetime:
    value = object_value(run, "current workflow run")
    require(integer(value.get("id"), "current run ID") == int(env["GITHUB_RUN_ID"]), "current run ID mismatch")
    require(value.get("name") == EXPECTED_CALLER_NAME, "current workflow name mismatch")
    require(value.get("path") == EXPECTED_CALLER_PATH, "current workflow path mismatch")
    require(value.get("event") == "push", "current workflow event is not push")
    require(value.get("head_branch") == "main", "current workflow branch is not main")
    require(value.get("head_sha") == env["GITHUB_SHA"], "current workflow SHA mismatch")
    validate_run_repository(value.get("repository"), "current run repository")
    exact_user(value.get("actor"), EXPECTED_ACTOR_ID, "joshcazalas", "current run actor")
    exact_user(value.get("triggering_actor"), EXPECTED_ACTOR_ID, "joshcazalas", "current run triggering actor")

    referenced = list_value(value.get("referenced_workflows"), "current referenced workflows")
    require(len(referenced) == 1, "current run must reference exactly one reusable workflow")
    expected_path = (
        f"{EXPECTED_REPOSITORY}/.github/workflows/"
        f"reusable-foundation-main-apply.yml@{trusted_sha}"
    )
    reusable = object_value(referenced[0], "current referenced workflow")
    require(reusable.get("path") == expected_path, "current reusable workflow is not pinned to the trusted SHA")
    require(reusable.get("sha") == trusted_sha, "current reusable workflow resolved to an unexpected SHA")
    return timestamp(value.get("created_at"), "current run created_at")


def validate_push_event(event: Any, env: Mapping[str, str]) -> None:
    value = object_value(event, "push event")
    require(env.get("GITHUB_EVENT_NAME") == "push", "foundation apply requires a push event")
    require(env.get("GITHUB_REF") == "refs/heads/main", "foundation apply requires refs/heads/main")
    require(env.get("GITHUB_REPOSITORY") == EXPECTED_REPOSITORY, "repository name mismatch")
    require(env.get("GITHUB_REPOSITORY_ID") == str(EXPECTED_REPOSITORY_ID), "repository ID mismatch")
    require(env.get("GITHUB_REPOSITORY_OWNER_ID") == str(EXPECTED_OWNER_ID), "repository owner ID mismatch")
    require(env.get("GITHUB_ACTOR_ID") == str(EXPECTED_ACTOR_ID), "workflow actor ID mismatch")
    require(env.get("GITHUB_WORKFLOW_REF") == f"{EXPECTED_REPOSITORY}/{EXPECTED_CALLER_PATH}@refs/heads/main", "caller workflow ref mismatch")
    require(value.get("ref") == "refs/heads/main", "push payload ref mismatch")
    require(value.get("after") == env.get("GITHUB_SHA"), "push payload SHA mismatch")
    require(value.get("deleted") is False and value.get("forced") is False, "forced or deleted pushes cannot authorize apply")
    require(value.get("before") != "0" * 40, "branch creation cannot authorize apply")
    head_commit = object_value(value.get("head_commit"), "push head commit")
    require(head_commit.get("id") == env.get("GITHUB_SHA"), "push head commit mismatch")
    validate_repository(value.get("repository"), "push repository")
    exact_user(value.get("sender"), EXPECTED_ACTOR_ID, "joshcazalas", "push sender")


def validate_plan_run(
    run: Any,
    pr: Mapping[str, Any],
    plan_run_id: int,
    trusted_sha: str,
    merged_at: datetime,
) -> None:
    value = object_value(run, "plan run")
    head = object_value(pr.get("head"), "pull request head")
    require(integer(value.get("id"), "plan run ID") == plan_run_id, "plan run ID mismatch")
    require(integer(value.get("workflow_id"), "plan workflow ID") == EXPECTED_PLAN_WORKFLOW_ID, "plan workflow ID mismatch")
    require(value.get("name") == EXPECTED_PLAN_NAME, "plan workflow name mismatch")
    require(value.get("path") == EXPECTED_PLAN_PATH, "plan workflow path mismatch")
    require(value.get("event") == "pull_request", "plan workflow event mismatch")
    require(value.get("status") == "completed" and value.get("conclusion") == "success", "plan run was not successful")
    require(value.get("head_sha") == head.get("sha"), "plan run head SHA mismatch")
    validate_run_repository(value.get("repository"), "plan run repository")
    exact_user(value.get("actor"), EXPECTED_ACTOR_ID, "joshcazalas", "plan run actor")
    exact_user(value.get("triggering_actor"), EXPECTED_ACTOR_ID, "joshcazalas", "plan run triggering actor")
    require(timestamp(value.get("updated_at"), "plan run updated_at") <= merged_at, "plan run completed after merge")

    pull_requests = list_value(value.get("pull_requests"), "plan run pull requests")
    require(len(pull_requests) == 1, "plan run must be associated with exactly one pull request")
    association = object_value(pull_requests[0], "plan run pull request")
    require(integer(association.get("number"), "plan run pull request number") == pr.get("number"), "plan run pull request mismatch")
    association_head = object_value(association.get("head"), "plan run pull request head")
    association_base = object_value(association.get("base"), "plan run pull request base")
    require(association_head.get("sha") == head.get("sha"), "plan run associated head SHA mismatch")
    require(association_base.get("ref") == "main", "plan run associated base mismatch")
    require(object_value(association_head.get("repo"), "plan run head repository").get("id") == EXPECTED_REPOSITORY_ID, "plan run head repository mismatch")
    require(object_value(association_base.get("repo"), "plan run base repository").get("id") == EXPECTED_REPOSITORY_ID, "plan run base repository mismatch")

    referenced = list_value(value.get("referenced_workflows"), "plan referenced workflows")
    require(len(referenced) == 1, "plan run must reference exactly one reusable workflow")
    expected_path = (
        f"{EXPECTED_REPOSITORY}/.github/workflows/"
        f"reusable-foundation-plan.yml@{trusted_sha}"
    )
    reusable = object_value(referenced[0], "plan referenced workflow")
    require(reusable.get("path") == expected_path, "plan reusable workflow was not pinned to the trusted SHA")
    require(reusable.get("sha") == trusted_sha, "plan reusable workflow resolved to an unexpected SHA")


def validate_artifacts(api: API, plan_run_id: int, head_sha: str) -> None:
    response = object_value(
        api.get(f"repos/{EXPECTED_REPOSITORY}/actions/runs/{plan_run_id}/artifacts?per_page=100"),
        "plan artifacts",
    )
    artifacts = list_value(response.get("artifacts"), "plan artifact list")
    require(response.get("total_count") == 4 and len(artifacts) == 4, "plan run must contain exactly four artifacts")
    require({artifact.get("name") for artifact in artifacts if isinstance(artifact, dict)} == EXPECTED_ARTIFACT_NAMES, "plan artifact names mismatch")
    for artifact_value in artifacts:
        artifact = object_value(artifact_value, "plan artifact")
        require(artifact.get("expired") is False, "plan artifact is expired")
        workflow_run = object_value(artifact.get("workflow_run"), "artifact workflow run")
        require(workflow_run.get("id") == plan_run_id, "artifact run ID mismatch")
        require(workflow_run.get("repository_id") == EXPECTED_REPOSITORY_ID, "artifact repository ID mismatch")
        require(workflow_run.get("head_repository_id") == EXPECTED_REPOSITORY_ID, "artifact head repository ID mismatch")
        require(workflow_run.get("head_sha") == head_sha, "artifact head SHA mismatch")


def authorize(
    api: API,
    env: Mapping[str, str],
    event: Any,
    sleeper: Callable[[float], None] = time.sleep,
) -> dict[str, str]:
    trusted_sha = env.get("TRUSTED_WORKFLOW_SHA", "")
    require(SHA.fullmatch(trusted_sha) is not None, "trusted reusable workflow SHA is invalid")
    require(SHA.fullmatch(env.get("GITHUB_SHA", "")) is not None, "main SHA is invalid")
    require(env.get("GITHUB_RUN_ID", "").isdigit(), "workflow run ID is invalid")
    validate_push_event(event, env)

    current_run = api.get(
        f"repos/{EXPECTED_REPOSITORY}/actions/runs/{env['GITHUB_RUN_ID']}"
    )
    run_created_at = validate_current_run(current_run, env, trusted_sha)
    pr = find_merged_pull_request(api, env["GITHUB_SHA"], run_created_at, sleeper)
    pr_number = integer(pr.get("number"), "pull request number")
    head_sha = object_value(pr.get("head"), "pull request head")["sha"]
    merged_at = timestamp(pr.get("merged_at"), "pull request merged_at")

    comments = api.get_all(
        f"repos/{EXPECTED_REPOSITORY}/issues/{pr_number}/comments"
    )
    plan_comments = []
    for comment_value in comments:
        comment = object_value(comment_value, "pull request comment")
        user = object_value(comment.get("user"), "comment author")
        body = comment.get("body")
        if (
            user.get("id") == EXPECTED_BOT_ID
            and user.get("login") == "github-actions[bot]"
            and user.get("type") == "Bot"
            and isinstance(body, str)
            and body.startswith(STICKY_COMMENT_MARKER)
        ):
            plan_comments.append(comment)
    require(len(plan_comments) == 1, "expected exactly one trusted sticky plan comment")
    comment = plan_comments[0]
    require(timestamp(comment.get("updated_at"), "plan comment updated_at") <= merged_at, "plan comment changed after merge")
    links = set(RUN_LINK.findall(comment["body"]))
    require(len(links) == 1, "plan comment must link exactly one workflow run")
    plan_run_id = int(next(iter(links)))

    plan_run = api.get(
        f"repos/{EXPECTED_REPOSITORY}/actions/runs/{plan_run_id}"
    )
    validate_plan_run(plan_run, pr, plan_run_id, trusted_sha, merged_at)
    validate_artifacts(api, plan_run_id, head_sha)

    return {
        "plan_run_id": str(plan_run_id),
        "pull_request_head_sha": head_sha,
        "pull_request_merged_at": pr["merged_at"],
        "pull_request_number": str(pr_number),
        "trusted_workflow_sha": trusted_sha,
    }


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} GITHUB_OUTPUT", file=sys.stderr)
        return 64

    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    token = os.environ.get("GH_TOKEN", "")
    if not event_path or not token:
        print("GITHUB_EVENT_PATH and GH_TOKEN are required.", file=sys.stderr)
        return 65

    try:
        event = json.loads(Path(event_path).read_text(encoding="utf-8"))
        api = GitHubAPI(os.environ.get("GITHUB_API_URL", "https://api.github.com"), token)
        outputs = authorize(api, os.environ, event)
        with Path(sys.argv[1]).open("a", encoding="utf-8") as output:
            for name, value in outputs.items():
                output.write(f"{name}={value}\n")
    except (OSError, UnicodeError, json.JSONDecodeError, AuthorizationError) as error:
        print(f"Foundation apply authorization failed: {error}", file=sys.stderr)
        return 1

    print(
        "Authorized merged pull request "
        f"#{outputs['pull_request_number']} with reviewed plan run "
        f"{outputs['plan_run_id']}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
