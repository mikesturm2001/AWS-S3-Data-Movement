# Define a variable to hold the names of S3 buckets as a list
variable "bucket_names" {
  type    = list(string)
  default = ["s3-drop-zone-12134477a", "snowflake-drop-zone-12134477a"]
}

# Create S3 buckets using the variable
resource "aws_s3_bucket" "s3_buckets" {
  count = length(var.bucket_names)

  bucket = var.bucket_names[count.index]
  acl    = "private"

  # Prevent Terraform from attempting to recreate an existing bucket
  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning, server-side encryption, and public access block for each S3 bucket
resource "aws_s3_bucket_versioning" "enabled" {
  count = length(var.bucket_names)

  bucket = aws_s3_bucket.s3_buckets[count.index].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  count = length(var.bucket_names)

  bucket = aws_s3_bucket.s3_buckets[count.index].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  count = length(var.bucket_names)

  bucket = aws_s3_bucket.s3_buckets[count.index].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}