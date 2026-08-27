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
  existing workload-account email aliases and a new deployment-account alias

After the organization root creates the deployment account, add and test:

- `mor-deployment`
- `mor-deployment-readonly`

Verify identity before every plan or apply:

```bash
aws sts get-caller-identity --profile mor-management
```

The expected management account is `357964519547`. Stop immediately if the
returned account differs.

## State bootstrap boundary

An S3 backend cannot create the bucket in which it stores its own state. The
management foundation bucket is therefore the only manually bootstrapped state
bucket. It stores the management-state, organization, platform, and GitHub
roots. The platform root later creates the centralized application-state bucket
in the deployment account while its own state remains safely in management.

Do not manually create per-environment state buckets. Do not put application
data in either state bucket.

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

Copy the example personal variables file and fill all three values locally. Use
the current aliases for the two existing accounts and a new, unique alias for
the deployment account. Never paste those addresses into an issue, PR, chat,
plan excerpt, or committed file.

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

AWS_PROFILE=mor-management tofu -chdir=terraform/organization \
  show organization.tfplan
```

The first plan is expected to:

- import the existing Organization, Workloads OU, two accounts, default
  security SCP, FullAWSAccess attachments, Identity Center permission sets,
  managed policies, and six existing account assignments;
- create the Deployments, NonProduction, and Production OUs;
- create exactly one new account named `deployment` under Deployments;
- rename the existing accounts to `workloads-uat` and `workloads-prod`;
- move those existing accounts under NonProduction and Production respectively;
- add BootstrapAdministrator and ReadOnly assignments for the new deployment
  account;
- preserve every imported FullAWSAccess attachment and rely on AWS's automatic
  default attachment for each new OU/account without removing the reviewed root
  security SCP; and
- create the organization, deployment, UAT, and production budgets plus their
  SNS notification path.

If the original organization root was applied before the deployment-hub
refactor, the plan also reports address-only moves for the two existing
accounts, their direct FullAWSAccess attachments, four Identity Center
assignments, and two linked-account budgets. These moves preserve the remote
objects and are not destroys, imports, or replacements. Do not remove
`prevent_destroy` to perform this migration.

Before considering apply, inspect the machine-readable action list:

```bash
tofu -chdir=terraform/organization show -json organization.tfplan |
  jq -r '
    .resource_changes[] |
    [
      .address,
      (.change.actions | join(",")),
      (if .change.importing == null then "" else "import" end)
    ] |
    @tsv
  '
```

Stop on any destroy, account close, replacement, OU deletion, policy
detachment, permission-set replacement, or unfamiliar resource. Existing
account email drift is intentionally ignored because the AWS provider models
that field as replacement-only; the configured deployment email is still used
when creating the new account.

### Post-organization account checks

After an explicitly approved organization apply:

1. In the AWS Organizations console, open **AWS accounts** and confirm this
   exact hierarchy and all three member accounts show **Active**:

   ```text
   Root
   ├── Deployments / deployment
   └── Workloads
       ├── NonProduction / workloads-uat
       └── Production / workloads-prod
   ```

2. In IAM Identity Center, open **AWS accounts**, select `deployment`, and
   confirm the current user has both `BootstrapAdministrator` and `ReadOnly`.
   Test both portal entries before continuing.

3. Add `mor-deployment` and `mor-deployment-readonly` SSO profiles using the
   same SSO session, start URL, region, and permission-set names as the existing
   profiles. Then prove every identity:

   ```bash
   aws sso login --profile mor-deployment
   aws sts get-caller-identity --profile mor-deployment
   aws sts get-caller-identity --profile mor-deployment-readonly
   aws sts get-caller-identity --profile mor-management
   aws sts get-caller-identity --profile mor-uat
   aws sts get-caller-identity --profile mor-prod
   ```

   Both deployment profiles must return the new deployment account ID. The
   other profiles must still return their original account IDs.

4. Verify centralized root credentials remain absent for the new account and
   update its primary and alternate contacts through the same root-only process
   used for the existing members. Do not create a member root password merely
   to inspect it. Stop if AWS shows recoverable root credentials or an
   unexpected root-access path.

5. This is the workstation-configuration gate: the AWS account/profile set is
   now stable enough to update Home Manager. Create the requested local-only
   handoff for the Nix agent at this point; do not put that handoff in either
   repository.

## Deployment platform

The platform root is authenticated with `mor-management` only for bootstrap.
Its aliased AWS providers assume the existing
`OrganizationAccountAccessRole` in deployment, UAT, and production. It creates:

- one protected application-state bucket in deployment;
- one GitHub OIDC provider in deployment;
- separate Money on Record plan/deploy hub roles for UAT and production;
- exact-trust Money on Record plan/deploy roles in both workload accounts; and
- account-level S3 Block Public Access in deployment while importing the
  already-enabled controls in UAT and production.

The initial configuration gives hub roles only permission to assume their exact
workload role. State access is intentionally disabled, and workload roles have
no workload permissions. This supports identity-only testing without granting
deployment capability.

Initialize and plan only after the organization apply and post-account checks
are complete:

```bash
aws sso login --profile mor-management
aws sts get-caller-identity --profile mor-management

AWS_PROFILE=mor-management tofu -chdir=terraform/platform init \
  -backend-config=backend.s3.tfbackend

AWS_PROFILE=mor-management tofu -chdir=terraform/platform plan \
  -out=platform-identity.tfplan

AWS_PROFILE=mor-management tofu -chdir=terraform/platform \
  show platform-identity.tfplan
```

The identity-only plan must import exactly the existing UAT and production
account-level S3 public-access blocks. It must not import or create a per-account
state bucket or OIDC provider. It may create the centralized deployment bucket,
its protections, deployment account S3 public-access block, one OIDC provider,
four deployment-account hub roles, and four workload-account execution roles.

Stop on any destroy, replacement, broad wildcard principal, cross-environment
trust, state permission while the enablement flags are false, or workload
permission. Review the saved plan and its JSON action list before requesting
explicit authorization for that exact apply.

## GitHub environments

The GitHub root creates the `uat` and `production` environments in
`joshcazalas/money-on-record`, restricts deployments to `main`, and stores only
non-secret account, workspace, role, region, and centralized state-bucket
variables. Environment deploy-role variables point to the deployment-account
hub, while repository plan-role variables contain separate UAT and production
hub roles. It authenticates to GitHub from `GITHUB_TOKEN`; the token must never
be placed in a Terraform variable, backend file, plan, or state.

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

## Role-chain gates

The deployment roles require the exact environment-scoped subject,
`refs/heads/main`, and matching GitHub Environment; production deployment also
requires Josh's immutable actor ID. Plan roles require the exact immutable
pull-request subject because main-only GitHub Environments cannot be used by
pull-request jobs. Every role also enforces immutable repository and owner IDs.

After the platform and GitHub roots are applied, use a reviewed GitHub workflow
to run identity-only positive tests for all four chains:

```text
GitHub UAT plan OIDC -> MoneyOnRecordPlanUat -> UAT MoneyOnRecordTerraformPlan
GitHub prod plan OIDC -> MoneyOnRecordPlanProd -> prod MoneyOnRecordTerraformPlan
GitHub UAT env OIDC -> MoneyOnRecordDeployUat -> UAT MoneyOnRecordTerraformDeploy
GitHub prod env OIDC -> MoneyOnRecordDeployProd -> prod MoneyOnRecordTerraformDeploy
```

Each final `aws sts get-caller-identity` must return the expected workload
account. Negative tests must prove that each hub role cannot assume the other
environment's workload role, a non-main deployment cannot obtain an environment
role, and the UAT role cannot read production state. Coordinate this workflow
with the Money on Record source-code agent; this foundation task does not modify
that repository.

Only after those tests succeed should a reviewed foundation change set
`money_on_record_plan_job_workflow_ref` to the exact trusted reusable workflow
on `main` and set `enable_money_on_record_state_access` to true for the proven
environment. Terraform rejects state enablement while that workflow condition
is absent. The subsequent platform plan must add only the exact workflow-ref
trust condition plus exact state-object and lock-object permissions. Plan roles
receive read-only state access and no lock writes; deploy roles receive state
read/write plus lock read/write/delete. Neither may read another application's
or environment's state object. Because OpenTofu enumerates named workspaces by
listing the component's `workspace_key_prefix`, both environments may see
object names beneath the same component prefix; that metadata-only list
permission does not grant `GetObject` on the other environment's state.

Application roots then use the single centralized bucket with component
prefixes such as `money-on-record/shared`, `money-on-record/static-site`, and
`money-on-record/etl`. They select only named `uat` or `production` workspaces,
and the provider assumes the matching workload execution role. Role chaining
caps the workload session at one hour; jobs must be designed to finish within
that bound.

## Budget email subscription

Terraform creates the budget SNS topic but deliberately does not manage a
personal email endpoint. After the topic exists, create and confirm its email
subscription out of band. Personal contact information must never enter Git,
saved plans, or Terraform state.

## Apply authorization

A successful plan is not permission to apply it. Each apply requires Josh's
explicit approval of that exact saved plan. No pull request may be merged by an
agent.
