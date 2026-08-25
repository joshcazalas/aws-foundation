output "state_bucket_arn" {
  description = "ARN of the management-account foundation state bucket."
  value       = aws_s3_bucket.foundation.arn
}

output "state_bucket_name" {
  description = "Name of the management-account foundation state bucket."
  value       = aws_s3_bucket.foundation.id
}
