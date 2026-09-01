import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
OIDC = (REPOSITORY_ROOT / "terraform/platform/github-oidc.tf").read_text(encoding="utf-8")
WORKLOAD = (REPOSITORY_ROOT / "terraform/platform/workload-execution.tf").read_text(
    encoding="utf-8"
)
VARIABLES = (REPOSITORY_ROOT / "terraform/platform/variables.tf").read_text(encoding="utf-8")
GITHUB = (REPOSITORY_ROOT / "terraform/github/environments.tf").read_text(encoding="utf-8")


class ArtifactPublisherContractTests(unittest.TestCase):
    def test_oidc_trust_is_exactly_main_uat_and_the_reusable_publisher(self) -> None:
        self.assertIn('hub_role_name      = "MoneyOnRecordArtifactPublishUat"', OIDC)
        self.assertIn(
            "name                 = local.money_on_record_uat_artifact_publisher.hub_role_name",
            OIDC,
        )
        self.assertIn(
            'default     = "joshcazalas/money-on-record/.github/workflows/'
            'reusable-site-publish.yml@refs/heads/main"',
            VARIABLES,
        )
        for claim in (
            "repository_id",
            "repository_owner_id",
            "environment",
            "ref",
            "job_workflow_ref",
        ):
            self.assertIn(f'token.actions.githubusercontent.com:{claim}', OIDC)
        self.assertIn(
            '${local.github_repository.subject_base}:environment:uat',
            OIDC,
        )
        self.assertIn('values   = ["refs/heads/main"]', OIDC)
        self.assertIn(
            'arn:aws:iam::${local.account_ids["workloads-uat"]}:role/'
            '${local.money_on_record_uat_artifact_publisher.workload_role_name}',
            OIDC,
        )

    def test_workload_role_is_uat_only_and_object_scoped(self) -> None:
        artifact_contract = WORKLOAD.split(
            'module "money_on_record_uat_artifact_publish_workload_role"', 1
        )[1].split('module "workloads_uat"', 1)[0]

        self.assertIn('workload_role_name = "MoneyOnRecordArtifactPublish"', OIDC)
        self.assertIn(
            "name                 = local.money_on_record_uat_artifact_publisher.workload_role_name",
            artifact_contract,
        )
        self.assertIn(
            'arn:aws:s3:::money-on-record-uat-${local.account_ids["workloads-uat"]}-site',
            WORKLOAD,
        )
        self.assertIn(
            'arn:aws:cloudfront::${local.account_ids["workloads-uat"]}:'
            'distribution/EEZ2CUTI93E10',
            WORKLOAD,
        )
        for action in (
            "s3:ListBucket",
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "cloudfront:CreateInvalidation",
            "cloudfront:GetInvalidation",
        ):
            self.assertIn(f'"{action}"', artifact_contract)
        self.assertNotIn("workloads-prod", artifact_contract)
        self.assertNotIn("MoneyOnRecordTerraformDeploy", artifact_contract)
        self.assertNotIn('resources = ["*"]', artifact_contract)

    def test_terraform_role_can_manage_only_account_local_response_policies(self) -> None:
        for action in (
            "cloudfront:CreateResponseHeadersPolicy",
            "cloudfront:GetResponseHeadersPolicy",
            "cloudfront:GetResponseHeadersPolicyConfig",
            "cloudfront:UpdateResponseHeadersPolicy",
            "cloudfront:DeleteResponseHeadersPolicy",
        ):
            self.assertIn(f'"{action}"', WORKLOAD)
        self.assertIn(
            'arn:aws:cloudfront::${configuration.account_id}:response-headers-policy/*',
            WORKLOAD,
        )

    def test_github_uat_environment_receives_non_secret_exact_targets(self) -> None:
        for variable in (
            "AWS_ARTIFACT_PUBLISH_ROLE_ARN",
            "AWS_ARTIFACT_PUBLISH_WORKLOAD_ROLE_ARN",
            "SITE_ARTIFACT_BUCKET",
            "SITE_CLOUDFRONT_DISTRIBUTION_ID",
            "SITE_URL",
        ):
            self.assertIn(f'"uat:{variable}"', GITHUB)
        self.assertIn("MoneyOnRecordArtifactPublishUat", GITHUB)
        self.assertIn("MoneyOnRecordArtifactPublish", GITHUB)
        self.assertIn("EEZ2CUTI93E10", GITHUB)
        self.assertIn("https://d32c1cs24r00f5.cloudfront.net", GITHUB)


if __name__ == "__main__":
    unittest.main()
