provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-data-movement-state-1447"

  # Prevent this bucket from getting deleted
  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning of this bucket
resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption by default
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Explicitly block all public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.terraform_state.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# Create DynamoDB to enable locking for terraform state
resource "aws_dynamodb_table" "terrform_locks" {
  name = "terraform-up-and-running-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

# Output the ARNs of the newly created objects
output "s3_bucket_arn" {
  description = "The ARN of the terraform S3 state bucket"
  value = aws_s3_bucket.terraform_state.arn
}

output "dynamoDB_arn" {
  description = "The ARN of the dynamoDB used to hold terraform locks"
  value = aws_dynamodb_table.terrform_locks.arn
}