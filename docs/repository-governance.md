# Repository visibility and governance

This document records the reviewed path from a private personal repository to
a public portfolio repository. It is not authorization to change visibility,
delete branches, or mutate GitHub settings. Josh must approve those exact
external changes after the preparation pull request is merged.

## Decision

The target visibility is public. Public visibility makes the architecture and
engineering evidence independently reviewable and unlocks repository rulesets
and GitHub security features on the current plan. The foundation is designed
so account IDs, role names, bucket names, immutable GitHub IDs, and topology
may be known without granting access.

The repository uses Apache License 2.0. Its explicit patent grant is a good fit
for a reusable public infrastructure reference while keeping commercial and
non-commercial reuse straightforward.

On the current GitHub Free plan, public repositories can use rulesets and
standard GitHub-hosted Actions runners without consuming private-repository
minutes. Artifact and cache storage limits still apply, and larger runners are
still billable. Remaining private would avoid intentional public disclosure,
but rulesets would require upgrading the GitHub plan and Actions would continue
using the private-repository allowance.

The tradeoff is permanent disclosure. Everyone can clone and fork the full
reachable history, and historical Actions runs and logs become visible. Making
the repository private later does not retract copies or public forks.

Revisit this decision before adding another maintainer, accepting substantial
external contributions, enabling a paid GitHub feature, changing the repository
owner or plan, storing new classes of sensitive input, or materially changing
the AWS/GitHub trust boundary. Revisit it immediately after any suspected
credential, state, or personal-data disclosure.

## Public-readiness audit

The 2026-08-31 audit covered the current tree, all GitHub remote branches, all
reachable commits and objects, issue and pull-request bodies and comments,
retained Actions artifacts, and every retained Actions log.

- Fifteen remote refs, 41 reachable commits, and 413 reachable Git objects were
  inventoried. Every non-main remote topic branch was already merged.
- No state, saved plan, real variable file, credential file, private key,
  local discovery output, or oversized blob is reachable.
- A fully redacted Gitleaks 8.30.1 scan, sourced from the repository's locked
  Nixpkgs revision, reported no leaks across Git history.
- Commit author and committer metadata uses GitHub-generated noreply addresses.
- The only repository email values are reserved `example.invalid` placeholders.
  The only issue-body email-pattern matches are the literal SSH remote
  `git@github.com`.
- All 36 retained workflow logs were checked without persisting their content.
  No access-key ID, GitHub token, private key, personal email, or SSO portal URL
  was found. One historical log contains only the name of the standard
  `AWS_SECRET_ACCESS_KEY` environment variable, not a credential value.
- Retained Actions artifacts use only the four `foundation-plan-*` names and
  contain the workflow's sanitized plan-result contract, never state, raw plan
  JSON, or binary plans.
- GitHub access has one administrator, no additional collaborator, no deploy
  key, and no webhook. The sole repository secret is the intentionally named
  organization-input secret; its value is not readable through GitHub.

The audit found no history rewrite requirement. Re-run it if any branch is
added or rewritten before the visibility change.

## Pull-request governance

The stable ruleset check is `Required pull request checks`. It aggregates every
offline check and then enforces one of two explicit outcomes:

- a branch in this repository must also pass all four trusted plans and the
  sanitized plan commenter; or
- a fork or manual run must have both privileged jobs skipped.

This lets a public fork satisfy one stable ruleset check without receiving AWS
OIDC or a write-capable `GITHUB_TOKEN`. The workflow never uses
`pull_request_target`.

The `main` ruleset should have no bypass actor and should:

- block deletion and force pushes;
- require a pull request, resolved review threads, and merge commits;
- require `Required pull request checks` from GitHub Actions;
- not require an approving review because the repository has one maintainer,
  who cannot approve his own pull request; and
- not require an up-to-date branch or merge queue, avoiding redundant plans for
  a single-maintainer repository.

Unsigned commits and linear history are intentionally not required. Requiring
them would add friction while conflicting with the reviewed merge-commit
workflow, without materially strengthening the OIDC boundary.

The required check is bound to GitHub Actions integration ID `15368`, as
observed on this repository's existing checks, so another status provider
cannot satisfy it using only the same context name.

## Actions and external-contributor policy

After the public switch:

- retain read-only default `GITHUB_TOKEN` permissions and continue preventing
  Actions from approving pull requests;
- require every Action reference to use a full-length commit SHA;
- allow GitHub-authored Actions plus only
  `aws-actions/configure-aws-credentials`, `opentofu/setup-opentofu`, and
  `terraform-linters/setup-tflint` from outside GitHub;
- require approval before running workflows from every external contributor;
- keep fork tokens read-only and never provide fork runs with secrets; and
- enable native secret scanning, push protection, dependency-graph alerts, and
  private vulnerability reporting.

Code scanning, third-party scanners, dependency-update automation, and release
attestations remain separate reviewed issues. Public visibility must not select
those tools implicitly.

## Reviewed configuration payloads

The JSON files in `.github/governance/` are inert review artifacts. No workflow
reads or applies them, and merging them changes no GitHub setting. They record
the exact intended payloads so the visibility rollout can be reviewed before
an administrator applies it:

| File | GitHub REST operation after approval |
|---|---|
| `repository-settings.json` | `PATCH /repos/joshcazalas/aws-foundation` |
| `main-ruleset.json` | `POST /repos/joshcazalas/aws-foundation/rulesets` |
| `actions-permissions.json` | `PUT /repos/joshcazalas/aws-foundation/actions/permissions` |
| `selected-actions.json` | `PUT /repos/joshcazalas/aws-foundation/actions/permissions/selected-actions` |
| `workflow-permissions.json` | `PUT /repos/joshcazalas/aws-foundation/actions/permissions/workflow` |
| `fork-approval.json` | `PUT /repos/joshcazalas/aws-foundation/actions/permissions/fork-pr-contributor-approval` |
| `security-and-analysis.json` | `PATCH /repos/joshcazalas/aws-foundation` after it is public |
| `topics.json` | `PUT /repos/joshcazalas/aws-foundation/topics` |

Dependency alerts and private vulnerability reporting use bodyless `PUT`
requests to `/vulnerability-alerts` and `/private-vulnerability-reporting`, so
they have no JSON payload to store. Apply the Actions allowlist before approving
any external workflow run. Local actions and reusable workflows remain allowed;
the explicit self-repository pattern permits the pinned reusable plan caller.

## External rollout

Perform these operations only after the preparation pull request is merged and
Josh approves the exact rollout:

1. Re-run the sensitive-history and retained-log audit.
2. Delete only the audited, merged remote topic branches Josh approves.
3. Change `joshcazalas/aws-foundation` from private to public.
4. Immediately create the active `main` ruleset described above.
5. Restrict Actions to the reviewed allowlist and require full-SHA pins.
6. Set external-contributor workflow approval to every outside contributor.
7. Enable secret scanning, push protection, dependency alerts, and private
   vulnerability reporting.
8. Allow merge commits only, delete merged branches automatically, and set the
   reviewed description and topics.
9. Open a harmless fork pull request and prove offline checks pass while every
   AWS-backed plan and comment job is skipped.
10. Open a same-repository documentation pull request and prove the aggregate
    check requires the trusted plans and commenter before merge.

Changing visibility automatically makes historical Actions logs public and
allows arbitrary forks. Visibility rollback is therefore an operational
setting change, not a confidentiality recovery mechanism.

## GitHub references

- [Repository visibility consequences](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility)
- [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
- [Ruleset availability](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [Actions repository settings](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository)
- [Approving workflow runs from forks](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/approve-runs-from-forks)
- [Configuring private vulnerability reporting](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting)
