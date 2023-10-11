# Set up back end state
terraform {
  backend "s3" {
    bucket         = "terraform-data-movement-state-1247"
    key            = "global/iam/terraform.tfstate"
    region         = "us-east-1"

    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}

# Fetch S3 bucket information
data "terraform_remote_state" "s3" {
  backend = "s3"
  config = {
    bucket = "terraform-data-movement-state-1247"
    key    = "global/s3/terraform.tfstate"
    region = "us-east-1"
  }
}

# Create an IAM role for EC2 instances to assume
resource "aws_iam_role" "ec2_role" {
  name = "ec2-s3-access-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  # Add a lifecycle block to handle the resource if it already exists
  lifecycle {
    ignore_changes = [tags, assume_role_policy]  # Ignore changes to tags
  }
}

# Attach an inline policy to the IAM role to grant S3 permissions
resource "aws_iam_policy" "s3_permissions_policy" {
  name        = "s3-access-policy"
  description = "Policy to access S3 buckets"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
        Effect   = "Allow",
        Resource = data.terraform_remote_state.s3.outputs.s3_bucket_arns
      }
    ]
  })
}

# need to get ec2 role as well
resource "aws_iam_role_policy_attachment" "s3_permissions_attachment" {
  policy_arn = aws_iam_policy.s3_permissions_policy.arn
  role       = aws_iam_role.ec2_role.name
}

# Create an instance profile for the EC2 instances
resource "aws_iam_instance_profile" "ec2_data_movement_instance_profile" {
  name = "ec2_data_movement_instance_profile"
  role = aws_iam_role.ec2_role.name
}