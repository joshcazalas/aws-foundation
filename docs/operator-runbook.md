# Operator runbook

This runbook intentionally separates bootstrap, plan, apply, and verification.
No command here uses a static AWS credential.

## Prerequisites

- OpenTofu 1.12.x
- AWS CLI v2
- Authenticated IAM Identity Center profiles:
  - `mor-management`
  - `mor-management-readonly`
  - `mor-uat`
  - `mor-uat-readonly`
  - `mor-prod`
  - `mor-prod-readonly`
- A local, ignored `terraform/organization/personal.auto.tfvars` containing the
  existing workload-account email aliases

Verify identity before every plan or apply:

```bash
aws sts get-caller-identity --profile mor-management
```

The expected management account is `357964519547`. Stop immediately if the
returned account differs.

## State bootstrap boundary

An S3 backend cannot create the bucket in which it stores its own state. The
only manually bootstrapped resources are therefore the state buckets and their
minimum protections. Terraform imports each bucket during its first plan and
owns all configuration after that point.

The exact bootstrap commands are run interactively after the corresponding
Terraform configuration has been reviewed. Do not create a bucket with a
different name and do not put application data in a state bucket.

## Management state

Target bucket:

```text
joshcazalas-aws-foundation-tfstate-357964519547
```

1. Refresh the administrator session and prove the target account:

   ```bash
   aws sso login --profile mor-management
   aws sts get-caller-identity --profile mor-management
   ```

   The returned account must be `357964519547`.

2. Check that the exact new bucket name is not already owned by this account:

   ```bash
   aws s3api head-bucket \
     --bucket joshcazalas-aws-foundation-tfstate-357964519547 \
     --profile mor-management
   ```

   For this first bootstrap only, `404` is expected. Stop on success, `403`, or
   any result suggesting the name is already in use.

3. Create the bucket in `us-east-1`:

   ```bash
   aws s3api create-bucket \
     --bucket joshcazalas-aws-foundation-tfstate-357964519547 \
     --region us-east-1 \
     --profile mor-management
   ```

4. Before writing state, enable all four bucket public-access blocks,
   versioning, SSE-S3, and bucket-owner-enforced ownership:

   ```bash
   aws s3api put-public-access-block \
     --bucket joshcazalas-aws-foundation-tfstate-357964519547 \
     --public-access-block-configuration \
       BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
     --profile mor-management

   aws s3api put-bucket-versioning \
     --bucket joshcazalas-aws-foundation-tfstate-357964519547 \
     --versioning-configuration Status=Enabled \
     --profile mor-management

   aws s3api put-bucket-encryption \
     --bucket joshcazalas-aws-foundation-tfstate-357964519547 \
     --server-side-encryption-configuration \
       '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":false}]}' \
     --profile mor-management

   aws s3api put-bucket-ownership-controls \
     --bucket joshcazalas-aws-foundation-tfstate-357964519547 \
     --ownership-controls '{"Rules":[{"ObjectOwnership":"BucketOwnerEnforced"}]}' \
     --profile mor-management
   ```

5. Initialize the backend and create a saved plan:

```bash
AWS_PROFILE=mor-management tofu -chdir=terraform/bootstrap/management-state init \
  -backend-config=backend.s3.tfbackend

AWS_PROFILE=mor-management tofu -chdir=terraform/bootstrap/management-state plan \
  -out=management-state.tfplan

AWS_PROFILE=mor-management tofu -chdir=terraform/bootstrap/management-state \
  show management-state.tfplan
```

Review the import and every proposed mutation before applying. Saved plans are
ignored and must never be committed.

The plan must import the bucket and existing account-level S3 public-access
configuration. It may create the bucket policy and Terraform resource records
for the protections set above. It must not replace or destroy the bucket.

## Organization

Copy the example personal variables file and fill it locally:

```bash
cp terraform/organization/personal.auto.tfvars.example \
  terraform/organization/personal.auto.tfvars
chmod 600 terraform/organization/personal.auto.tfvars
```

Then initialize and plan:

```bash
AWS_PROFILE=mor-management tofu -chdir=terraform/organization init \
  -backend-config=backend.s3.tfbackend

AWS_PROFILE=mor-management tofu -chdir=terraform/organization plan \
  -out=organization.tfplan
```

The first plan must consist only of declared imports, intentional normalization,
and the reviewed new budget-notification resources. Stop on any account close,
OU deletion, policy detachment, permission-set replacement, or unfamiliar
resource.

## GitHub environments

The GitHub root creates the `uat` and `production` environments in
`joshcazalas/money-on-record`, restricts deployments to `main`, and stores only
non-secret account, role, region, and state-bucket variables. It authenticates
to GitHub from the `GITHUB_TOKEN` environment variable; the token must never be
placed in a Terraform variable, backend file, plan, or state.

After management state exists, initialize and plan with both authenticated
sessions available:

```bash
export GITHUB_TOKEN="$(gh auth token)"

AWS_PROFILE=mor-management tofu -chdir=terraform/github init \
  -backend-config=backend.s3.tfbackend

AWS_PROFILE=mor-management tofu -chdir=terraform/github plan \
  -out=github.tfplan
```

Unset the shell variable after the GitHub apply and verification:

```bash
unset GITHUB_TOKEN
```

## Account baselines

Each workload account uses a physically separate root and backend. Bootstrap
the buckets with the same five S3 commands used above, substituting the exact
profile and bucket below:

| Environment | Profile | Expected account | Bucket |
|---|---|---:|---|
| UAT | `mor-uat` | `732006412638` | `money-on-record-uat-732006412638-tfstate` |
| Production | `mor-prod` | `134604497564` | `money-on-record-prod-134604497564-tfstate` |

For `us-east-1`, do not add a `LocationConstraint` to `create-bucket`.

After each bucket is protected, initialize and plan its matching root.

UAT:

```bash
aws sso login --profile mor-uat
aws sts get-caller-identity --profile mor-uat

AWS_PROFILE=mor-uat tofu -chdir=terraform/accounts/money-on-record-uat init
AWS_PROFILE=mor-uat tofu -chdir=terraform/accounts/money-on-record-uat plan \
  -out=account-baseline.tfplan
```

Production:

```bash
aws sso login --profile mor-prod
aws sts get-caller-identity --profile mor-prod

AWS_PROFILE=mor-prod tofu -chdir=terraform/accounts/money-on-record-prod init
AWS_PROFILE=mor-prod tofu -chdir=terraform/accounts/money-on-record-prod plan \
  -out=account-baseline.tfplan
```

Each first plan must import its state bucket and existing account-level S3
public-access configuration. It may create only the reviewed bucket controls,
GitHub OIDC provider, and empty-permission plan/deploy role shells. State access
remains disabled until the identity-only OIDC tests pass.

The deployment roles require the exact environment-scoped subject,
`refs/heads/main`, and matching GitHub Environment; production deployment also
requires Josh's immutable actor ID. Plan roles instead require the exact
immutable pull-request subject because main-only GitHub Environments cannot be
used by pull-request jobs. Both role types require the immutable repository and
owner IDs and initially have no AWS permissions. Before plan permissions are
enabled, the trusted-plan workflow must be reviewed and its exact reusable
`job_workflow_ref` condition should be added to the plan-role trust policy.

## Budget email subscription

Terraform creates the budget SNS topic but deliberately does not manage a
personal email endpoint. After the topic exists, create and confirm its email
subscription out of band. Personal contact information must never enter Git,
saved plans, or Terraform state.

## Apply authorization

A successful plan is not permission to apply it. Each apply requires Josh's
explicit approval of that exact saved plan. No pull request may be merged by an
agent.
