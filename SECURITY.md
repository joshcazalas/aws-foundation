# Security policy

## Supported version

Only the current `main` branch is supported. Historical revisions and pull
request branches are retained as review evidence, not maintained releases.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting flow from the repository's
**Security** tab. Do not include credentials, personal data, exploit details,
Terraform/OpenTofu state, saved plans, or sensitive logs in a public issue or
pull request.

If private reporting is temporarily unavailable, open a public issue that says
only that private security coordination is needed. Do not describe the
vulnerability until the maintainer provides a private channel.

This is a personal, non-commercial project and does not operate a bug-bounty
program. Good-faith reports are still welcome and will be handled as promptly
as the project's scope permits.

## Scope and operating assumptions

AWS account IDs, organization topology, role names, resource names, and GitHub
identity IDs in this repository are intentional public architecture metadata,
not authentication secrets. Authorization must remain effective when all of
that metadata is known.

Never test a report by changing AWS or GitHub resources, attempting to assume a
role, accessing state or application data, or causing cost without explicit
written authorization from the maintainer.
