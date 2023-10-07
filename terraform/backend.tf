# backend.tf

terraform {
  backend "s3" {
    bucket         = "terraform-data-movement-state-1347"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}