output "drop_zone_bucket" {
  description = "S3 bucket for loading files to AWS"
  value = aws_s3_bucket.s3-drop-zone
}

output "drop_zone_bucket_name" {
  description = "Name of the S3 bucket for loading files to AWS"
  value = aws_s3_bucket.s3-drop-zone.bucket
}

output "drop_zone_bucket_id" {
  description = "Id of the S3 bucket for loading files to AWS"
  value = aws_s3_bucket.s3-drop-zone.id
}

output "drop_zone_bucket_arn" {
  description = "ARN of the S3 bucket for loading files to AWS"
  value = aws_s3_bucket.s3-drop-zone.arn
}

output "snowflake_bucket" {
  description = "S3 bucket for loading files to snowflake"
  value = aws_s3_bucket.s3-snowflake-zone
}

output "snowflake_bucket_name" {
  description = "Name of the S3 bucket for loading files to snowflake"
  value = aws_s3_bucket.s3-snowflake-zone.bucket
}

output "snowflake_bucket_id" {
  description = "Id of the S3 bucket for loading files to snowflake"
  value = aws_s3_bucket.s3-snowflake-zone.id
}

output "snowflake_bucket_arn" {
  description = "ARN of the S3 bucket for loading files to snowflake"
  value = aws_s3_bucket.s3-snowflake-zone.arn
}

output "s3_bucket_arns" {
  description = "ARN of the S3 bucket for loading files to snowflake"
  value = [aws_s3_bucket.s3_drop_zone_bucket.arn, aws_s3_bucket.s3-snowflake-zone.arn]  
}