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

The phase-two probe is documentation-only so every Terraform root should report
no infrastructure changes. After its first run passes, this section records the
run and sticky-comment evidence in a second commit. That second run verifies the
existing marked bot comment is updated in place.

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
temporary directory. Only redacted CLI text and tested action counts are
uploaded for the no-AWS-permission comment job.

## Deployment remains deferred

No phase in this runbook creates an automatic apply path. Apply workflows,
GitHub Environments, reviewers, locking, release coupling, and rollback remain
a separate design decision.
