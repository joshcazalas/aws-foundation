import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
POLICY = (REPOSITORY_ROOT / "terraform/platform/workload-execution.tf").read_text(
    encoding="utf-8"
)
OIDC = (REPOSITORY_ROOT / "terraform/platform/github-oidc.tf").read_text(encoding="utf-8")
GITHUB = (REPOSITORY_ROOT / "terraform/github/environments.tf").read_text(encoding="utf-8")


class SiteObjectPermissionContractTests(unittest.TestCase):
    def test_existing_terraform_roles_own_exact_environment_site_objects(self) -> None:
        for action in (
            "s3:GetObject",
            "s3:GetObjectTagging",
            "s3:PutObject",
            "s3:PutObjectTagging",
            "s3:DeleteObject",
            "s3:DeleteObjectTagging",
        ):
            self.assertIn(f'"{action}"', POLICY)

        self.assertIn('resources = ["${resources.bucket_arn}/*"]', POLICY)
        self.assertIn("local.money_on_record_static_site_read_permissions", POLICY)
        self.assertIn("local.money_on_record_static_site_deploy_permissions", POLICY)

    def test_no_parallel_artifact_identity_or_github_configuration_exists(self) -> None:
        for prohibited in (
            "MoneyOnRecordArtifactPublish",
            "artifact_publish",
            "CreateInvalidation",
            "GetInvalidation",
        ):
            self.assertNotIn(prohibited, POLICY + OIDC + GITHUB)


if __name__ == "__main__":
    unittest.main()
