# Define a variable to hold the names of S3 buckets as a list
variable "bucket_names" {
  description = "List of S3 buckets used as drop zones for data movement"
  type    = list(string)
  default = ["s3-drop-zone-12134477a", "snowflake-drop-zone-12134477a"]
}

# Create S3 buckets using the variable
resource "aws_s3_bucket" "s3_buckets" {
  for_each = toset(var.bucket_names)

  bucket = each.key

  # Prevent Terraform from attempting to recreate an existing bucket
  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning, server-side encryption, and public access block for each S3 bucket
resource "aws_s3_bucket_versioning" "enabled" {
  for_each = aws_s3_bucket.s3_buckets

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption at rest by default
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  for_each = aws_s3_bucket.s3_buckets

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to the S3 buckets
resource "aws_s3_bucket_public_access_block" "public_access" {
  for_each = aws_s3_bucket.s3_buckets

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}