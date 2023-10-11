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
