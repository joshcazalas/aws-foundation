# Contributing

Issues and focused pull requests are welcome. This repository manages security
boundaries for a live personal AWS organization, so reviewability and safe
defaults matter more than generalized abstractions.

Unless explicitly stated otherwise, submitted contributions are licensed under
the repository's [Apache License 2.0](LICENSE).

## Before opening a pull request

- Open or reference an issue for changes that affect account structure, IAM,
  organization policy, state, GitHub OIDC, or repository governance.
- Keep application infrastructure in its application repository.
- Never commit credentials, personal contact details, AWS account email
  addresses, SSO portal URLs, state, saved plans, local variable files, or
  discovery output.
- Pin third-party GitHub Actions to full commit SHAs and Terraform modules to
  exact registry versions.
- Enter `nix develop` and run `just validate`.

## Pull-request trust boundary

Fork pull requests receive offline validation only. They cannot receive AWS
credentials, update the sticky Terraform plan comment, or reach an apply role.
If an external contribution is accepted, the maintainer reproduces it on a
branch in this repository before using the trusted read-only plan workflow.

Pull-request plans are informational previews. They are never reused as apply
artifacts. Only merged `main` can reach the separate AWS apply identities, and
only the maintainer decides whether a pull request is merged.

## Review expectations

Keep changes small enough to review against the issue's security boundary.
Explain permission additions, state migrations, replacement or destroy
actions, new costs, and any manual rollout step. Do not weaken tests or trust
conditions merely to make a plan pass.
