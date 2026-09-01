# CI bootstrap runbook

This runbook establishes pull-request planning without long-lived AWS
credentials. It deliberately separates trust creation from live planning so the
AWS role can require the permanent reusable workflow on `main` from its first
successful assumption.

## Phase 1: permanent identity and offline checks

The first CI pull request contains:

- parallel OpenTofu format and per-root validation jobs;
- per-root TFLint jobs with the pinned AWS plugin;
- a repository-hygiene check;
- the permanent `reusable-foundation-plan.yml` workflow in identity-only mode;
- a management-account GitHub OIDC plan role with exact repository, owner,
  pull-request subject, and `job_workflow_ref` conditions; and
- one read-only foundation plan role in each member account.

The pull request itself cannot run AWS-backed plans because its trusted reusable
workflow does not exist on `main` yet. Review and merge it only after its local
plans show the expected additions and no unrelated changes.

After merge, update local `main`, authenticate the `management` profile, and
apply in this order:

```bash
aws sso login --profile management
aws sts get-caller-identity --profile management

AWS_PROFILE=management tofu -chdir=terraform/organization init \
  -backend-config=backend.s3.tfbackend -reconfigure
AWS_PROFILE=management tofu -chdir=terraform/organization plan \
  -out=foundation-ci.tfplan
AWS_PROFILE=management tofu -chdir=terraform/organization show \
  foundation-ci.tfplan
# Stop here until Josh explicitly approves this exact saved plan.
AWS_PROFILE=management tofu -chdir=terraform/organization apply \
  foundation-ci.tfplan

AWS_PROFILE=management tofu -chdir=terraform/platform init \
  -backend-config=backend.s3.tfbackend -reconfigure
AWS_PROFILE=management tofu -chdir=terraform/platform plan \
  -out=foundation-ci.tfplan
AWS_PROFILE=management tofu -chdir=terraform/platform show \
  foundation-ci.tfplan
# Stop here until Josh explicitly approves this exact saved plan.
AWS_PROFILE=management tofu -chdir=terraform/platform apply \
  foundation-ci.tfplan
```

The local platform provider continues to assume
`OrganizationAccountAccessRole`. CI later overrides
`member_account_access_role_name` with `AWSFoundationTerraformPlan`; do not set
that override for a local apply.

Saved plan files are local-only and ignored. Do not commit or upload them.

## Phase 2: trusted plans and sticky comment

The second CI pull request calls the identity-only reusable workflow from
`main`. That proves all of the following before live planning is merged:

- the pull-request OIDC subject and immutable repository/owner IDs;
- the exact main-branch `job_workflow_ref`;
- management-account identity;
- read access to exactly the four foundation state objects; and
- tagged role chaining into deployment, UAT, and production.

GitHub's repository OIDC settings expose the immutable subject prefix
`repo:joshcazalas@73436834/aws-foundation@1346584597`. The management role
therefore binds that prefix plus `:pull_request`, in addition to separately
checking the repository and owner ID claims.

That pull request then replaces the reusable workflow body with the live,
read-only plan implementation and adds the sticky comment aggregator. Its own
run still uses the identity-only workflow already on `main`; a small follow-up
probe pull request exercises the newly merged live planner end to end.

Before opening that probe, set the repository Actions secret without printing
its value or creating a temporary plaintext file. From the repository root,
with the ignored `personal.auto.tfvars` still containing the reviewed map, run:

```bash
printf 'jsonencode(var.account_emails)\n' |
  AWS_PROFILE=management tofu -chdir=terraform/organization console \
    -var-file=personal.auto.tfvars |
  jq -r . |
  gh secret set TF_VAR_account_emails \
    --repo joshcazalas/aws-foundation
```

Confirm only the secret name and update time; GitHub never returns its value:

```bash
gh secret list --repo joshcazalas/aws-foundation
```

The probe pull request must receive four successful trusted plan jobs, one
sticky production-first comment, and the normal offline checks. A second push
to the same probe must update the existing bot comment instead of adding a
second marked comment. Fork pull requests must skip both AWS-backed jobs.

### Live-plan verification record

The first phase-two probe reached live planning in all four roots. Management
state, GitHub, and Platform reported no changes. Organization exposed a missing
`budgets:ListTagsForResource` read permission, and all four jobs exposed a
slug-directory mismatch in sanitized artifact publication. The trusted-script
bootstrap fix adds that one read action, corrects the artifact layout, and adds
a runner-level regression test. A fresh documentation-only probe after that fix
merges must report no changes in every scope and update its marked bot comment
in place on a second push.

The post-fix verification uses this documentation-only change. Its first run
must create the corrected production-first comment from four sanitized plan
artifacts. A second commit records the immutable run and comment evidence and
must update that same bot comment rather than creating another.

The first corrected run is
[`33189211642`](https://github.com/joshcazalas/aws-foundation/actions/runs/33189211642).
All four roots succeeded with zero changes. Each artifact contained only its
slugged `metadata.json` and redacted `plan.txt`; no binary plan or raw JSON was
present. GitHub rendered Production, UAT, Deployment, Management, and GitHub as
five real level-three headings. The single marked bot comment ID was
`5454935554`, created at `2026-08-28T16:17:56Z`. This evidence commit triggers
the required in-place update check.

The organization root also requires the sensitive `account_emails` input. Live
CI receives it from a repository Actions secret named
`TF_VAR_account_emails`, encoded as the same JSON object used locally. It is
configuration data, not an AWS credential, and must never be printed, included
in a comment, or committed.

The GitHub-provider root runs with `-refresh=false` in pull-request CI. GitHub's
built-in `GITHUB_TOKEN` cannot request the Environment and Variables API
permissions required to refresh that root. This state-based preview avoids a
PAT or GitHub App private-key secret. Manual plans remain the authoritative way
to check live GitHub drift until a separately reviewed GitHub App design is
adopted.

The plan jobs use `-lock=false` and `-detailed-exitcode`; their saved plans are
never reused for apply. Binary plans and raw JSON exist only in an ephemeral
temporary directory. Only redacted CLI text, a sanitized address/action
manifest, and a SHA-256 digest of the canonical resource/output change
projection are uploaded for the no-AWS-permission comment job.

## Main-only apply activation

Pull-request subjects remain planning-only. Never broaden an apply role to the
`pull_request` subject. All three apply roles retain the immutable main-only
subject:

```text
repo:joshcazalas@73436834/aws-foundation@1346584597:ref:refs/heads/main
```

The direct apply workflow is the remaining OIDC boundary. Trust also requires
the immutable repository and owner IDs, Josh's actor ID, the separate
`refs/heads/main` claim, the workflow name, and this exact workflow ref:

```text
joshcazalas/aws-foundation/.github/workflows/foundation-apply.yml@refs/heads/main
```

Before merging the cleanup PR, use a fresh local organization saved plan to
replace the old reusable-workflow `job_workflow_ref` condition with the direct
`workflow_ref` condition. Review that only the three apply-role trust policies
change, apply the exact saved plan, and then re-run the PR plan. The re-run must
show no remaining trust-policy changes.

After merge, the `push` event supplies the main-ref subject. The direct workflow
runs management-state, organization, and platform in order. Each job receives
only `contents: read` and `id-token: write`, performs one automatic apply, and
requires a final no-change plan. It does not call the GitHub API or inspect PR
comments and artifacts.

No GitHub App, PAT, or GitHub Environment is part of AWS authentication. The
GitHub-provider root remains manual because its provider requires the
operator's short-lived GitHub CLI token; its changed plan comment includes the
commands.

Before making the repository public, protect `main`: require pull requests and
required checks, block force pushes and branch deletion, require review for
workflow and bootstrap changes, and require approval for external-contributor
workflow runs. External fork PRs receive offline validation only. Reproduce an
accepted external change on a branch in this repository before running an
AWS-backed plan.
