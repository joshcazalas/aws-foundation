# Repository agent instructions

## Safety

- Treat this repository as public even while its GitHub visibility is private.
- Never commit AWS credentials, Terraform/OpenTofu state, saved plans, personal
  contact details, account email addresses, SSO portal URLs, tokens, or local
  discovery output.
- Do not create, close, or move AWS accounts without Josh's explicit approval
  of the exact plan.
- Never run `tofu apply`, `terraform apply`, or any destructive AWS command
  without Josh's explicit approval of that specific plan.
- Do not deploy application workloads from this repository.

## Pull requests

- Agents may create and update pull requests when that is part of the requested
  work.
- Never merge a pull request unless Josh explicitly authorizes merging that
  specific pull request after it is ready for his review.
- Leave pull requests open for Josh by default and report their URL and status.
