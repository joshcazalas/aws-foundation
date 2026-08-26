# AWS Foundation

Terraform-compatible infrastructure for Josh Cazalas's AWS Organizations
foundation. OpenTofu is the authoritative CLI, while the repository uses
Terraform language, conventions, providers, and modules.

The foundation separates organization governance, deployment control, and
application workloads:

```text
AWS Organization root
├── management account
│   ├── Organizations, SCPs, IAM Identity Center, and budgets
│   └── foundation-only Terraform state
├── Deployments OU
│   └── deployment account
│       ├── centralized application Terraform state
│       └── GitHub OIDC and per-application/per-environment hub roles
└── Workloads OU
    ├── NonProduction OU
    │   └── workloads-uat
    └── Production OU
        └── workloads-prod
```

Application infrastructure belongs in the application repository. This
repository owns organization governance, the deployment platform, account
baselines, state storage, and bootstrap identities.

## Design principles

- AWS workload accounts are the UAT/production security boundary.
- Human access uses IAM Identity Center and short-lived sessions.
- GitHub enters AWS once through environment-specific deployment-account roles,
  then assumes an exact least-privilege role in the target workload account.
- Application roots use named `uat` and `production` CLI workspaces against one
  shared configuration; the `default` workspace is not deployable.
- Organization and state resources are protected from accidental destruction.
- Foundation state remains in management. Application state is centralized in
  the deployment account and separated by application, component, and workspace.
- Terraform state uses private, versioned S3 buckets with native S3 lockfiles.
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
  platform/             Deployment state, OIDC hub, and workload execution roles
  github/               Deployment environments and non-secret variables
  modules/
    github-environment-roles/    Reusable OIDC hub-role pair
    workload-execution-baseline/ Reusable workload-account role pair
```

Each runnable foundation root has a separate state boundary. The platform root
uses aliased AWS providers to assume `OrganizationAccountAccessRole` from an
authenticated management session while establishing the long-term deployment
role chain. Application roots live in their application repositories and assume
those roles without management-account access.

The S3 account-public-access and IAM role abstractions use exact releases of
`terraform-aws-modules`. State buckets use direct AWS resources because the
upstream bucket module does not expose the resource-level `prevent_destroy`
lifecycle guard required here.

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

1. Create only the management state bucket and its minimum backend protections,
   then import and harden it with `terraform/bootstrap/management-state`.
2. Import existing organization resources and create the reviewed account/OU
   structure with `terraform/organization`.
3. Add the deployment account to local IAM Identity Center profiles and finish
   its out-of-band root/contact checks.
4. Create the centralized state bucket and identity-only role chain with
   `terraform/platform`.
5. Create the GitHub deployment environments and non-secret variables with
   `terraform/github`.
6. Run positive and negative OIDC role-chain tests.
7. Enable state access in `terraform/platform`, retest, and only then permit an
   application repository to initialize named workspaces.

Exact commands and verification gates live in
[`docs/operator-runbook.md`](docs/operator-runbook.md). No AWS apply is intended
to run in CI yet.

The production-grade pull-request checks and sticky plan-comment contract are
recorded in [`docs/ci-design.md`](docs/ci-design.md). They are intentionally not
implemented until the manually applied foundation is proven and deployment
semantics have been designed.
