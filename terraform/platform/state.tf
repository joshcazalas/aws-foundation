locals {
  application_state_bucket_name = "joshcazalas-deployment-tfstate-${local.account_ids["deployment"]}"
}

data "aws_iam_policy_document" "application_state" {
  provider = aws.deployment

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.application_state.arn,
      "${aws_s3_bucket.application_state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }

    condition {
      test     = "Bool"
      variable = "aws:PrincipalIsAWSService"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyOutdatedTLS"
    effect = "Deny"

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.application_state.arn,
      "${aws_s3_bucket.application_state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }

    condition {
      test     = "Bool"
      variable = "aws:PrincipalIsAWSService"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket" "application_state" {
  provider = aws.deployment

  bucket        = local.application_state_bucket_name
  force_destroy = false

  tags = {
    Component = "application-state"
    Purpose   = "Centralized Terraform state for application workloads"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "application_state" {
  provider = aws.deployment

  bucket = aws_s3_bucket.application_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  skip_destroy            = true
}

resource "aws_s3_bucket_ownership_controls" "application_state" {
  provider = aws.deployment

  bucket = aws_s3_bucket.application_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "application_state" {
  provider = aws.deployment

  bucket = aws_s3_bucket.application_state.id

  versioning_configuration {
    status = "Enabled"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "application_state" {
  provider = aws.deployment

  bucket = aws_s3_bucket.application_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }

    bucket_key_enabled = false
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_policy" "application_state" {
  provider = aws.deployment

  bucket = aws_s3_bucket.application_state.id
  policy = data.aws_iam_policy_document.application_state.json

  depends_on = [aws_s3_bucket_public_access_block.application_state]

  lifecycle {
    prevent_destroy = true
  }
}

module "deployment_account_public_access" {
  providers = {
    aws = aws.deployment
  }

  source  = "terraform-aws-modules/s3-bucket/aws//modules/account-public-access"
  version = "5.15.4"

  account_id = local.account_ids["deployment"]

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
