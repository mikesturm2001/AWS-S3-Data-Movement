output "s3_bucket_names" {
  description = "Names of the S3 buckets"
  value       = [for bucket_name in aws_s3_bucket.s3_buckets : bucket_name.bucket]
}

output "s3_bucket_ids" {
  description = "IDs of the S3 buckets"
  value       = values(aws_s3_bucket.s3_buckets)[*].id
}

output "s3_bucket_arns" {
  description = "ARNs of the S3 buckets"
  value       = values(aws_s3_bucket.s3_buckets)[*].arn
}