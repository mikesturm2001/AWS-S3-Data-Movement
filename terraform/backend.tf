# backend.tf

terraform {
  backend "s3" {
    bucket         = "terraform-data-movement-state-1347"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"

    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}