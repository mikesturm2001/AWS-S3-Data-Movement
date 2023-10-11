output "s3_drop_zone_bucket_id" {
  value = aws_s3_bucket.s3-drop-zone.id
}

output "snowflake_drop_zone_bucket_id" {
  value = aws_s3_bucket.snowflake-drop-zone.id
}