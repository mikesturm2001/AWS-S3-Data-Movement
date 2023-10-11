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

# Create an instance profile for the EC2 instances
resource "aws_iam_instance_profile" "ec2_data_movement_instance_profile" {
  name = "ec2_data_movement_instance_profile"
  role = aws_iam_role.ec2_role.name
}
