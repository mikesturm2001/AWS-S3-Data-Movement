output "s3_bucket_names" {
  description = "Names of the S3 buckets"
  value       = [for bucket_name in aws_s3_bucket.s3_buckets : bucket_name.bucket]
}

output "drop_zone_bucket" {
  description = "Names of the S3 bucket for loading files to AWS"
  value = aws_s3_bucket.s3-drop-zone
}

output "drop_zone_bucket_arn" {
  description = "Names of the S3 bucket for loading files to AWS"
  value = aws_s3_bucket.s3-drop-zone.arn
}

output "snowflake_bucket" {
  description = "Arn of the S3 bucket for loading files to snowflake"
  value = aws_s3_bucket.s3-snowflake-zone
}

output "snowflake_bucket_arn" {
  description = "Names of the S3 bucket for loading files to snowflake"
  value = aws_s3_bucket.s3-snowflake-zone.arn
}

output "s3_bucket_ids" {
  description = "IDs of the S3 buckets"
  value       = values(aws_s3_bucket.s3_buckets)[*].id
}

output "s3_bucket_arns" {
  description = "ARNs of the S3 buckets"
  value       = values(aws_s3_bucket.s3_buckets)[*].arn
}