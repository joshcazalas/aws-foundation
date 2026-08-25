# AWS Foundation

Terraform-compatible infrastructure for Josh Cazalas's AWS Organizations
foundation. OpenTofu is the authoritative CLI, while the repository uses
Terraform language, conventions, providers, and modules.

The foundation separates organization governance from application workloads:

```text
AWS Organizations management account
├── Organizations, SCPs, IAM Identity Center, budgets
├── foundation governance state
└── Workloads OU
    ├── money-on-record-uat
    └── money-on-record-prod
```

Application infrastructure belongs in the application repository. This
repository owns only organization governance, account baselines, state storage,
and bootstrap identities.

## Design principles

- AWS accounts are the UAT/production security boundary.
- Human access uses IAM Identity Center and short-lived sessions.
- GitHub access uses environment-scoped OIDC; no static AWS credentials exist.
- Organization and state resources are protected from accidental destruction.
- Terraform state uses private, versioned S3 buckets with native lockfiles.
- `terraform-aws-modules` is pinned exactly where its abstraction fits.
- Organization and account changes are applied manually until the complete
  workflow has been reviewed and proven.
- The repository contains no personal contact details or account email aliases.

## Repository layout

```text
terraform/
  bootstrap/
    management-state/   Imports and hardens the management state bucket
  organization/         Organization, accounts, SCPs, access, and budgets
  github/               Deployment environments and non-secret variables
  accounts/
    money-on-record-uat/  UAT state boundary and guarded provider
    money-on-record-prod/ Production state boundary and guarded provider
  modules/
    workload-account-baseline/ Reusable state and OIDC baseline
```

Each runnable root has a separate state boundary. The two small workload-account
roots call the same baseline module while pinning their own account ID, backend,
environment, and immutable GitHub OIDC claims.

## Tooling

Enter the Nix development shell:

```bash
nix develop
```

Authenticate with the AWS CLI profiles documented in
[`docs/operator-runbook.md`](docs/operator-runbook.md), then use `tofu` for all
plans and applies. Never provide static credentials through variables or backend
configuration.

## Bootstrap order

1. Create only the management state bucket and its minimum backend protections
   using the documented bootstrap commands.
2. Import and harden it with `terraform/bootstrap/management-state`.
3. Import existing organization resources with `terraform/organization`.
4. Create the GitHub deployment environments with `terraform/github`.
5. Create each workload state bucket using the same narrow bootstrap procedure.
6. Import and apply the matching root under `terraform/accounts` for each
   workload account.
7. Run positive and negative access tests before granting workload permissions.

Exact commands and verification gates live in
[`docs/operator-runbook.md`](docs/operator-runbook.md). No AWS apply is intended
to run in CI yet.

The production-grade pull-request checks and sticky plan-comment contract are
recorded in [`docs/ci-design.md`](docs/ci-design.md). They are intentionally not
implemented until the manually applied foundation is proven and deployment
semantics have been designed.
