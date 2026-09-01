# AWS Foundation

Terraform-compatible infrastructure for Josh Cazalas's AWS Organizations
foundation. OpenTofu is the authoritative CLI, while the repository uses
Terraform language, conventions, providers, and modules.

This repository manages the AWS organization, identity, state, and deployment
foundations used by my personal projects. Public resource identifiers and
account topology are intentional; credentials, personal contact details,
state, saved plans, and sensitive inputs are not part of the repository. See
the [security policy](SECURITY.md) for vulnerability reporting guidance.

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
- Foundation pull-request plans use a separate read-only management-account
  OIDC role and dedicated read-only roles in every member account.
- Application roots use named `uat` and `production` CLI workspaces against one
  shared configuration; the `default` workspace is not deployable.
- Organization and state resources are protected from accidental destruction.
- Foundation state remains in management. Application state is centralized in
  the deployment account and separated by application, component, and workspace.
- Terraform state uses private, versioned S3 buckets with native S3 lockfiles.
- `terraform-aws-modules` is pinned exactly where its abstraction fits.
- Merged `main` is the trust boundary for ordered foundation applies; pull
  requests can use only the separate read-only planning identity.
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
    foundation-account-plan-role/ Reusable member-account foundation plan role
    github-environment-roles/    Reusable OIDC hub-role pair
    workload-execution-baseline/ Reusable workload-account role pair
```

Each runnable foundation root has a separate state boundary. The platform root
uses aliased AWS providers to assume `OrganizationAccountAccessRole` from an
authenticated management session while establishing the long-term deployment
role chain. Pull-request CI overrides that provider role with the read-only
`AWSFoundationTerraformPlan` role. Application roots live in their application
repositories and assume their own roles without management-account access.

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
7. After the identity gate passes and permanent reusable workflows reach
   `main`, bind their exact `job_workflow_ref` claims and enable scoped state and
   workload permissions in `terraform/platform`.
8. Retest the tightened chains before permitting an application repository to
   initialize named workspaces or deploy resources.
9. Bootstrap the foundation repository's read-only OIDC plan chain, then enable
   trusted same-repository pull-request plans and the sticky plan comment.
10. Bind the apply roles to the direct `foundation-apply.yml` workflow on
    `refs/heads/main`, then activate ordered `push`-to-`main` applies.
11. Move foundation CI identities into the manual security-bootstrap root so
    automatic apply roles cannot rewrite their own trust or permissions.

Exact commands and verification gates live in
[`docs/operator-runbook.md`](docs/operator-runbook.md). Pull-request subjects
are always planning-only; only the direct workflow running from protected
`main` can assume the AWS apply roles.

The production-grade pull-request checks and sticky plan-comment contract are
recorded in [`docs/ci-design.md`](docs/ci-design.md). Their two-phase trust
sequence is documented in [`docs/ci-bootstrap.md`](docs/ci-bootstrap.md).
Monthly dependency proposals and their maintainer-promotion workflow are
documented in [`docs/dependency-maintenance.md`](docs/dependency-maintenance.md).
AWS-root applies use a main-only OIDC subject and direct workflow name. The
GitHub-provider root remains manual because it requires the
operator's short-lived GitHub CLI session. See
[`docs/ci-design.md`](docs/ci-design.md) for the root-by-root policy and
bootstrap sequence.

Pull-request CI runs formatting, hygiene, per-root validation and TFLint,
workflow/script linting, tested plan-result rendering, and—only for
Josh-triggered branches in this repository—four no-lock read-only plans through
the trusted reusable workflow on `main`. Fork and automation-authored pull
requests receive offline checks only. Dependabot proposals must be promoted to
a maintainer-owned branch before the required check and trusted plans can pass.
The sticky plan comment is ordered Production, UAT, Deployment, Management,
then GitHub; it never serves as an apply artifact.

One aggregate check named `Required pull request checks` is the stable branch
governance contract. Josh-triggered same-repository pull requests must pass both
offline and trusted-plan jobs; fork pull requests must pass offline jobs while
the AWS and comment jobs remain skipped. Automation-authored same-repository
proposals remain unmergeable until promoted.

## License

Licensed under the [Apache License 2.0](LICENSE).
