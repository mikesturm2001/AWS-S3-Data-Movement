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

