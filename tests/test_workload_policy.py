import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
POLICY_PATH = REPOSITORY_ROOT / "terraform" / "platform" / "workload-execution.tf"


class WorkloadPolicyContractTests(unittest.TestCase):
    def test_static_site_provider_reads_use_exact_resource_boundaries(self) -> None:
        source = POLICY_PATH.read_text(encoding="utf-8")

        self.assertRegex(source, r"account_id\s*=\s*configuration\.account_id")
        self.assertIn('"s3:GetBucketAcl"', source)
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
