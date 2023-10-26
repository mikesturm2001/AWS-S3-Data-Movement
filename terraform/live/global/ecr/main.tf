# Set up back end state
terraform {
  backend "s3" {
    bucket         = "terraform-data-movement-state-1247"
    key            = "global/ecr/terraform.tfstate"
    region         = "us-east-1"

    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"  # Set your desired AWS region
}

resource "aws_ecr_repository" "aws_s3_data_movement_repository" {
  name = "aws_s3_data_movement_repository" 
}

# Create an ECR repository policy to allow ECS tasks to pull images
data "aws_iam_policy_document" "ecr_repository_policy" {
  statement {
    actions   = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetAuthorizationToken",
      "ecr:GetImage",
      "ecr:BatchGetImage",
    ]
    resources = [aws_ecr_repository.aws_s3_data_movement_repository.arn]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Attach the ECR repository policy to the ECR repository
resource "aws_ecr_repository_policy" "ecr_policy" {
  repository  = aws_ecr_repository.aws_s3_data_movement_repository.name
  policy      = data.aws_iam_policy_document.ecr_repository_policy.json
}

