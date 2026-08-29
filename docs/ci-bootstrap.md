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
AWS_PROFILE=management tofu -chdir=terraform/organization apply \
  foundation-ci.tfplan

AWS_PROFILE=management tofu -chdir=terraform/platform init \
  -backend-config=backend.s3.tfbackend -reconfigure
AWS_PROFILE=management tofu -chdir=terraform/platform plan \
  -out=foundation-ci.tfplan
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

## Apply bootstrap

The apply path is intentionally delivered in two pull requests:

1. Merge the bootstrap PR containing the permanent but inert
   `reusable-foundation-apply.yml`, reviewed-plan digest/manifest contract, and
   distinct root-specific apply roles. It has no merged-PR caller and therefore
   cannot start an apply.
2. Locally make fresh locked organization and platform saved plans, inspect
   them, validate their generated IAM policies with IAM Access Analyzer, and
   apply only those exact plans after Josh explicitly approves each one.
3. Prove the permitted main-workflow role chains and deny PR, fork, wrong-ref,
   wrong-workflow, cross-root state, application-state, and cross-environment
   attempts.
4. Merge the separate activation PR containing the `pull_request: closed`
   caller. Its first run must converge with no changes before a later harmless
   reviewed mutation is used to prove an actual apply.

After activation, merging a same-repository PR as Josh authorizes only the
successful plan for that exact pull-request revision. The post-merge job makes
a new locked plan and requires both its canonical digest and its sanitized
manifest to equal the reviewed values before applying that new saved plan.
Management-state, organization, and platform run in order and fail closed.
The GitHub-provider root remains manual because it requires the operator's
short-lived GitHub CLI token; its changed plan comment includes the commands.

No GitHub App or GitHub Environment is part of the AWS authentication path.
The AWS roles use GitHub's OIDC token with exact repository, actor, ref, and
reusable-workflow claim restrictions.
