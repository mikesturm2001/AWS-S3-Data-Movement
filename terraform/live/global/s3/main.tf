# Set up back end state
terraform {
  backend "s3" {
    bucket         = "terraform-data-movement-state-1247"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"

    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}

# Create S3 buckets for drop zone
resource "aws_s3_bucket" "s3-drop-zone" {

  bucket = var.s3_drop_zone_bucket

  # Prevent Terraform from attempting to recreate an existing bucket
  lifecycle {
    prevent_destroy = true
  }
}

# Create S3 buckets for loading into snowflake
resource "aws_s3_bucket" "s3-snowflake-zone" {

  bucket = var.s3_snowflake_bucket

  # Prevent Terraform from attempting to recreate an existing bucket
  lifecycle {
    prevent_destroy = true
  }
}

# Define a local variable to hold the names of S3 buckets as a list
locals {
  s3_buckets = {
    src = aws_s3_bucket.s3-drop-zone, 
    dst = aws_s3_bucket.s3-snowflake-zone
  }
}


# Enable versioning, server-side encryption, and public access block for each S3 bucket
resource "aws_s3_bucket_versioning" "enabled" {
  for_each = local.s3_buckets

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  for_each = local.s3_buckets
  bucket = each.value.id
  eventbridge = true
}

# Enable encryption at rest by default
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  for_each = local.s3_buckets

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to the S3 buckets
resource "aws_s3_bucket_public_access_block" "public_access" {
  for_each = local.s3_buckets

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}