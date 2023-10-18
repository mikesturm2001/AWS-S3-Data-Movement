# Set up back end state
terraform {
  backend "s3" {
    bucket         = "terraform-data-movement-state-1247"
    key            = "global/vpc/terraform.tfstate"
    region         = "us-east-1"

    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "data_movement_vpc" {
  cidr_block = "10.0.0.0/16"
}

locals {
  # Define a list of availability zones
  availability_zones = ["a", "b", "c"]  # Add more as needed

  # Create a map to associate numbers with availability zones
  az_to_number = {
    "a" = 1
    "b" = 2
    "c" = 3
    # Add more mappings if you have more availability zones
  }
}

resource "aws_subnet" "public_subnet" {
  count          = 1
  vpc_id         = aws_vpc.my_vpc.id
  cidr_block     = "10.0.1.0/24"
  availability_zone = "us-east-1${local.availability_zones[count.index]}"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnets" {
  count = 2
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.${count.index * 64}/26"  # Adjust CIDR block as needed
  availability_zone = "us-east-1${local.availability_zones[count.index+1]}"  # Choose a valid availability zone
  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

resource "aws_vpc_endpoint" "s3_endpoints" {
  count = 2
  vpc_id = aws_vpc.my_vpc.id
  service_name = "com.amazonaws.us-east-1.s3"
  route_table_ids = [aws_vpc.my_vpc.default_route_table_id]
}