# CI design

This document records the acceptance criteria for GitHub Actions automation.
It is a design contract; repository changes still require review, and no local
or bootstrap apply is authorized merely by editing this document.

## Hard requirements

- Pull-request checks run independently and in parallel wherever their inputs
  do not depend on one another.
- Every pull request runs recursive formatting checks, validation for every
  runnable root, and TFLint with the AWS plugin. Eligible Josh-triggered pull
  requests also run the trusted plan preview.
- The plan preview is published as the sticky, production-first comment defined
  in this document, including per-root collapsed detail and a CI-run link.
- OpenTofu is the authoritative state engine. Terraform-compatible source lives
  under `terraform/`; CI must not alternate Terraform and OpenTofu against the
  same state.
- Every third-party GitHub Action is pinned to its full commit SHA. A release
  tag may appear in an adjacent comment for readability, but must not be the
  executable reference.
- CI receives no long-lived AWS credentials. AWS-backed foundation jobs use
  GitHub OIDC to assume a dedicated read-only management-account plan role.
  That role can assume only the dedicated read-only foundation plan role in
  each member account. Application deployment identities are separate and
  cannot access organization or foundation state.
- A pull-request plan is an informational post-merge preview. The main workflow
  runs a fresh automatic apply against current configuration and state; it does
  not reuse or cryptographically bind itself to the pull-request plan.
- Trivy is excluded from the toolchain.
- No agent may merge a pull request or apply a plan without Josh's explicit
  authorization for that specific action.
- Public branch governance requires the stable aggregate check named
  `Required pull request checks`.
- Dependabot is proposal-only automation. Bot-authored pull requests receive no
  AWS-backed plan, secret, approval, merge, or apply capability and must be
  promoted unchanged to a maintainer-owned branch before trusted planning.

## Candidates to evaluate

These checks are intentionally recorded without selecting a tool or making them
required yet:

- native, plan-only OpenTofu tests for reusable-module invariants;
- generated-documentation drift checks with `terraform-docs`;
- dependency lockfile and exact-version policy enforcement beyond read-only
  initialization;
- Terraform security and compliance scanning, with Checkov and a focused
  OPA/Conftest policy set as the leading options;
- GitHub Actions security linting with `zizmor`;
- secret detection beyond GitHub's native secret scanning and push protection,
  such as Gitleaks;
- dependency review beyond GitHub's native public-repository support;
- cost-change reporting, such as Infracost, if its external service and data
  handling are acceptable; and
- OpenSSF Scorecard.

Trivy is not a candidate. Standalone tfsec is also not preferred because its
development path was folded into Trivy.

## Pull-request checks

The complete candidate check suite currently contains the following jobs. Only
rows marked **required** are locked for the initial implementation.

| Check | Status | Purpose |
|---|---|---|
| `fmt` | **Required** | Run `tofu fmt -check -recursive terraform` and reject formatting drift. |
| `validate` | **Required** | For every runnable root, run `tofu init -backend=false -lockfile=readonly` and `tofu validate`. |
| `tflint` | **Required** | Run TFLint's recommended Terraform rules and the pinned AWS ruleset for every root. |
| `plan` | **Required** | Produce the trusted-PR, no-lock preview described below for every applicable Terraform root. |
| `workflow-lint` | **Required** | Run pinned `actionlint`, pinned `shellcheck`, Bash syntax checks, and plan-result parser/renderer tests. |
| `required` | **Required** | Aggregate offline results, require trusted plans/comments only for Josh-triggered same-repository pull requests, and reject automation-authored proposals until promoted. This is the single stable ruleset context. |
| `lockfiles` | Candidate | Reject missing or unexpectedly changed dependency lockfiles and enforce the final version policy. |
| `tests` | Candidate | Run native, plan-only `tofu test` suites when module invariants are added. Tests that can apply infrastructure are forbidden in PR CI. |
| `docs` | Candidate | Regenerate module documentation with the pinned `terraform-docs` version and reject a non-empty diff once generated docs are adopted. |
| `security-policy` | Candidate | Scan Terraform source and, where useful, sanitized plan JSON with a separately approved and pinned policy engine. Checkov and OPA/Conftest remain under review. |

GitHub's native secret scanning and push protection are enabled. CI also rejects
tracked state, saved plans, local variable files, credentials, and personal
contact data. Dependabot provides monthly grouped version proposals for GitHub
Actions, OpenTofu, and the public Nix flake; its operating and incident-response
procedure is documented in `docs/dependency-maintenance.md`. GitHub's native
dependency graph and pull-request dependency review remain informational rather
than adding another required Action.

## Local tooling inventory

The repository's Nix development shell is the authoritative project toolset.
Installing the same tools through Home Manager is optional but useful when they
should be available outside this repository.

| Tool | Status | In `nix develop` now | Why it is useful locally |
|---|---|---:|---|
| OpenTofu | Required | Yes | Format, initialize, validate, test, plan, and apply. |
| AWS CLI v2 | Required | Yes | Identity Center login, bootstrap, and read-back verification. |
| GitHub CLI | Required for repository operations | Yes | Authentication, pull requests, checks, and releases. |
| `jq` | Required helper | Yes | Parse AWS and plan metadata without fragile text matching. |
| `just` | Required helper | Yes | Run the repository's documented command recipes. |
| TFLint | Required CI check | Yes | Terraform linting and AWS-specific rules. |
| `terraform-docs` | Candidate | Yes | Deterministic generated module documentation. |
| `actionlint` | Required CI check | Yes | Static validation of GitHub Actions workflows. |
| `shellcheck` | Required CI check | Yes | Shell-script correctness and portability checks. |
| Python 3 | Required helper | Yes | Test and render sanitized plan-result comments. |
| Checkov | Candidate | No | Broad built-in Terraform security policies. |
| Conftest | Candidate | No | Small repository-owned OPA policy set. |
| `zizmor` | Candidate | No | GitHub Actions security analysis. |
| Gitleaks | Candidate | No | Local and CI secret detection. |
| Infracost | Candidate | No | Pull-request cost-change estimates. |

This table is the running handoff list for workstation tooling. Update it when
a candidate becomes accepted or rejected. Do not add every candidate to Home
Manager preemptively.

## Plan trust boundary

AWS-backed plans may run only for Josh-triggered branches in this repository.
They must use the `pull_request` event and must never use `pull_request_target`
to execute pull-request-controlled Terraform. Fork and automation-authored pull
requests receive only offline checks; their plan rows remain skipped.

The final aggregate job always runs. Josh-triggered same-repository pull
requests fail unless offline checks, all trusted plans, and the plan comment
succeed. Automation-authored same-repository pull requests fail after proving
both privileged jobs were skipped; they must be promoted to a maintainer-owned
branch. Fork pull requests pass when offline checks succeed and both privileged
jobs are skipped. The public `main` ruleset requires only this aggregate
context, so it does not depend on conditionally absent reusable-workflow check
names.

The pinned reusable planner independently enforces this boundary before its
OIDC-enabled job starts. It requires Josh's immutable actor ID, Josh as the
rerun initiator, this repository's immutable head/base IDs, `main` as the base,
the exact PR merge ref caller, and an allowlisted root. A fork cannot bypass
that check by editing the caller workflow.

Each foundation plan job receives only:

- `contents: read`;
- `id-token: write` while obtaining its management-account AWS session;
- read access to exactly the four foundation state objects;
- read-only management-account control-plane permissions required by the
  bootstrap and organization roots; and
- permission to assume only `AWSFoundationTerraformPlan` in deployment, UAT,
  and production. Those roles expose only Terraform-managed control-plane
  configuration and, where Terraform owns a public static site, that exact
  environment's public delivery objects required for provider refresh. They
  never expose credentials, secrets, private application data, or state.

Plan-role trust must bind the exact immutable-ID pull-request subject
`repo:joshcazalas@73436834/aws-foundation@1346584597:pull_request` plus the
immutable repository and owner ID claims. It also binds the reusable workflow's
exact `job_workflow_ref`. It cannot require a main-only GitHub Environment or
`refs/heads/main`, because pull-request jobs use a PR merge ref.

The comment aggregation job receives no AWS token and no cloud permissions. It
receives only `actions: read`, `contents: read`, and `pull-requests: write` so
it can download sanitized results and update the pull-request comment.

Plan jobs use `-input=false`, `-lock=false`, and `-no-color`. Superseded runs
are cancelled. Apply workflows use root-specific non-cancelling concurrency
and plan again with state locking enabled.

Saved binary plans and raw `tofu show -json` output can contain sensitive
values and must not be uploaded as artifacts or posted to GitHub. A plan job may
temporarily create a plan file on its ephemeral runner, render the normal
redacted CLI view, derive its summary, and delete the file before handing a
sanitized text result to the comment job. Sanitized result artifacts are
retained for seven days; the complete redacted text also remains in the plan
job log linked by the comment.

The organization root receives its sensitive `account_emails` variable from a
repository Actions secret named `TF_VAR_account_emails`. It is not an AWS
credential. It is available only to that plan job and must never be printed or
passed to the commenter.

The GitHub-provider root uses `-refresh=false` in pull-request CI. The built-in
`GITHUB_TOKEN` does not offer the Environment and Variables API permissions
needed for a live provider refresh. A state-based preview is preferable to
introducing a PAT or GitHub App private key into PR CI. Manual authenticated
plans remain responsible for live GitHub drift until a separate design is
approved.

## Trust bootstrap

CI is introduced in two pull requests. The first landed the permanent reusable
workflow path in identity-only mode together with offline checks and the IAM
configuration. After that pull request was merged, its organization and
platform plans were manually applied. The second pull request calls the
main-branch identity-only workflow to prove the exact OIDC and role-chain
boundaries before replacing its body with live planning and adding the sticky
commenter. A small follow-up pull request then probes the merged live workflow.
See `docs/ci-bootstrap.md` for the operator sequence.

## Sticky plan comment

Exactly one bot comment per pull request uses this hidden marker:

```html
<!-- aws-foundation-terraform-plan -->
```

The commenter searches for the marker and updates its own existing comment. It
creates a new comment only when no matching comment exists. It must not edit a
human-authored comment containing a copied marker.

The visible comment begins with:

```markdown
## Terraform Plan - post-merge preview

Expected changes after merge. The main workflow plans again against current state.
```

It then renders a compact environment summary:

```markdown
| Env | Plan |
|---|---|
| Production | No changes. Your infrastructure matches the configuration. |
| UAT | 1 to add, 1 to change, 0 to destroy. |
| Management | No changes. Your infrastructure matches the configuration. |
```

The exact order is Production, UAT, Deployment, Management, then GitHub. A
failed or missing plan is shown explicitly and never represented as "no
changes."

Below the table, render one section per environment in the same order. Within
each environment, every Terraform root has a collapsed details block whose
summary contains the root and result:

```html
<details>
<summary><code>terraform/platform</code> — 1 to add, 1 to change, 0 to destroy</summary>

...formatted plan...

</details>
```

The expanded plan uses a Markdown `diff` fence. Create lines retain `+` for
green, destroy lines retain `-` for red, and update indicators are converted
only in this presentation copy from `~` to `!` for yellow. The underlying plan
is never changed.

The comment ends with a `View CI run` link built from the repository and run
ID. GitHub comments have a finite body size, so the complete sanitized plan is
included only while it fits. If it does not fit, the comment preserves every
summary and root result, truncates detail deterministically, labels the
truncation, and links to the retained CI log. Failure to fit the entire plan
must never prevent the summary comment from being updated.

When the GitHub root has changes, append a manual post-merge reminder before
the run link. It shows the short-lived `gh auth token` export, backend
initialization, fresh saved plan, plan review, exact saved-plan apply, and token
cleanup commands from the operator runbook. The GitHub root remains manual;
the reminder never carries a token and never treats the PR preview as the plan
to apply.

## Plan result handling

Use `tofu plan -detailed-exitcode` and distinguish all three outcomes:

- `0`: successful plan with no changes;
- `2`: successful plan with changes;
- any other exit code: failed plan.

Counts should be derived from a tested parser rather than from job success
alone. The aggregation job must still run when an individual plan fails so the
comment can identify the failed environment and link to its logs. The overall
required check remains failed.

## Foundation apply design

The protected `main` branch is the automatic-apply trust boundary. Pull-request
workflows can assume only the read-only plan role. The write-capable roles
require the immutable repository and owner IDs, Josh's actor ID, the exact
main-ref subject and `ref` claim, and the direct workflow name. No pull-request
OIDC subject can satisfy that trust policy. AWS IAM supports GitHub's `workflow`
claim but does not expose `workflow_ref` as a trust-policy condition key.

A push that updates `main` runs the three AWS roots in order. Each root uses
`tofu apply -auto-approve`, which creates and immediately applies its own fresh
plan while honoring the state lock. A final detailed-exit-code plan must report
no changes. The pull-request comment remains useful review information, but it
is not an authorization artifact and no PR binary plan is uploaded or reused.

| Root | Identity and state boundary | Trigger and ordering | Failure/recovery |
|---|---|---|---|
| `terraform/bootstrap/management-state` | Direct OIDC to `AWSFoundationManagementStateApply`; read/write only its exact state object and lock; manage only the exact foundation-state bucket and management-account S3 public-access setting. | First after a push updates `main`. | Stop on apply failure or non-convergence. Local saved-plan recovery remains supported. |
| `terraform/organization` | Direct OIDC to `AWSFoundationOrganizationApply`; read/write only organization state; service-scoped organization, Identity Center, budget/SNS, and exact foundation-automation IAM resources. | Runs after management-state succeeds. The sensitive account-email map is available only in this job. | No automatic rollback. Correct configuration or state deliberately, then use a newly reviewed PR. |
| `terraform/platform` | Direct OIDC to `AWSFoundationPlatformApply`; read/write only platform state, read only organization state, and assume only `AWSFoundationTerraformApply` in deployment/UAT/production. Member roles manage exact foundation/application IAM control-plane resources and the exact deployment state-bucket configuration, never application objects or application state contents. | Runs after organization succeeds. | Cross-account or convergence failure stops the chain. Use the documented local path for recovery. |
| `terraform/github` | No CI apply identity. | Never applied automatically. A changed PR comment prints the manual commands. | Authenticate through the existing short-lived `gh` CLI session, make a fresh saved plan, review it, and apply it locally. |

All automatic roots are deliberately ordered management-state, organization,
then platform in the direct workflow. A failure prevents later roots from
starting. Non-cancelling sequence concurrency prevents two main updates from
mutating foundation state simultaneously. Pull-request plans remain lock-free
and informational, so they do not contend with an apply lock.

No GitHub Environment, GitHub App, PAT, GitHub API authorization gate, artifact
download, or reusable apply workflow is required for AWS authentication. The
workflow receives only `contents: read` and `id-token: write`; it does not need
Actions or pull-request API permissions. The organization account-email value
remains available only to the organization job.

### Apply bootstrap sequence

1. Open the follow-up PR containing the direct main workflow and AWS-supported
   trust conditions.
2. Manually create, inspect, and apply that branch's exact organization saved
   plan so the apply roles no longer require unsupported `workflow_ref`.
3. Re-run the PR plan and require no remaining AWS trust changes.
4. Merge the follow-up PR. Its main push runs the direct ordered workflow and must
   converge without changes.

A following security-bootstrap change moves the foundation OIDC providers,
foundation plan/apply roles, their permission boundaries, and member foundation
plan/apply roles out of automatically applied roots. Automatic roles must not
be able to rewrite their own trust or permissions or modify/remove their
boundary. Changes to that small root are planned in CI but applied manually.

Manual recovery never reuses a PR plan. The operator creates a new locked saved
plan locally, reviews it, obtains explicit authorization for that exact plan,
applies it, and requires a final no-change plan. Automatic rollback is not used
for organization, IAM, or state infrastructure; failures are forward-fixed.

## Implementation references

- [OpenTofu formatting command](https://opentofu.org/docs/cli/commands/fmt/)
- [OpenTofu native tests](https://opentofu.org/docs/cli/commands/test/)
- [TFLint configuration](https://github.com/terraform-linters/tflint/blob/master/docs/user-guide/config.md)
- [TFLint AWS ruleset](https://github.com/terraform-linters/tflint-ruleset-aws)
- [GitHub Actions secure use](https://docs.github.com/en/actions/reference/security/secure-use)
- [Dependabot version updates](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/configure-version-updates)
- [Dependabot-triggered Actions restrictions](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-on-actions)
- [AWS IAM OIDC condition keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_iam-condition-keys.html#condition-keys-wif)
- [Checkov project](https://github.com/bridgecrewio/checkov)
- [Conftest project](https://github.com/open-policy-agent/conftest)
- [actionlint project](https://github.com/rhysd/actionlint)
- [zizmor project](https://github.com/zizmorcore/zizmor)
- [Gitleaks project](https://github.com/gitleaks/gitleaks)
- [tfsec-to-Trivy migration notice](https://github.com/aquasecurity/tfsec)
