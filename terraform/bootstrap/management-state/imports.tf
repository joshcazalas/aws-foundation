# The S3 bucket is the one deliberate manual bootstrap resource. Once this
# import is applied, Terraform owns its complete configuration.
import {
  to = aws_s3_bucket.foundation
  id = var.state_bucket_name
}

# Account-level S3 Block Public Access was enabled during the manual security
# bootstrap and is adopted here without replacement.
import {
  to = module.account_public_access.aws_s3_account_public_access_block.this[0]
  id = var.management_account_id
}
