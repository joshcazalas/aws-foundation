import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
POLICY_PATH = REPOSITORY_ROOT / "terraform" / "platform" / "workload-execution.tf"


class WorkloadPolicyContractTests(unittest.TestCase):
    def test_static_site_provider_reads_use_exact_resource_boundaries(self) -> None:
        source = POLICY_PATH.read_text(encoding="utf-8")

        self.assertRegex(source, r"account_id\s*=\s*configuration\.account_id")
        expected_bucket_reads = {
            "s3:GetAccelerateConfiguration",
            "s3:GetBucketAcl",
            "s3:GetBucketCORS",
            "s3:GetBucketLocation",
            "s3:GetBucketLogging",
            "s3:GetBucketObjectLockConfiguration",
            "s3:GetBucketOwnershipControls",
            "s3:GetBucketPolicy",
            "s3:GetBucketPolicyStatus",
            "s3:GetBucketPublicAccessBlock",
            "s3:GetBucketRequestPayment",
            "s3:GetBucketTagging",
            "s3:GetBucketVersioning",
            "s3:GetBucketWebsite",
            "s3:GetEncryptionConfiguration",
            "s3:GetLifecycleConfiguration",
            "s3:GetReplicationConfiguration",
            "s3:ListBucket",
            "s3:ListTagsForResource",
        }
        for action in expected_bucket_reads:
            self.assertIn(f'"{action}"', source)
        self.assertIn(
            '"arn:aws:cloudfront::${resources.account_id}:cache-policy/'
            '658327ea-f89d-4fab-a63d-7e88639e58f6"',
            source,
        )
        self.assertIn(
            '"arn:aws:cloudfront::${resources.account_id}:response-headers-policy/'
            '67f7725c-6f97-4210-82d7-5512b31e9d03"',
            source,
        )
        self.assertNotIn("arn:aws:cloudfront::aws:cache-policy/", source)
        self.assertNotIn("arn:aws:cloudfront::aws:response-headers-policy/", source)


if __name__ == "__main__":
    unittest.main()
