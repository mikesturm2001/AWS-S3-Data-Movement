# AWS-S3-Data-Movement
Using EC2 to move files between S3 buckets

## What is this project

This project is an example proof of concept application the can be used to move files between AWS S3 buckets. It's purpose is just a very high level example of the minimum AWS infrastrucutre and code that would be needed to build a simple ETL application. 

The primary purpose of this application would be loading data files into a datalake such as S3, Snowflake or Redshift. 

## Prerequisites

The project demonstrates how to use the following technologies

- Python (3+)
- Go
- AWS account and IAM credentials
- Docker
- Terraform

## Getting Started

### Deploy to AWS Via Terraform

Github actions are used to deploy terraform to AWS there are several actions

- terraform_state_init   - this will create the terraform backend
- aws_ecr_creation       - this will create the ECR registry to store container images
- ecr                    - this will create the docker image and publish it to artifactory
- aws_vpc_creation       - this will create the VPC for the application
- aws_s3_buckets         - this will create the S3 buckets for the application
- aws_iam                - used to create all iam roles
- aws_application_deploy - this will deploy all AWS application infrastructure (SNS, SQS, ASGs, Cloud Watch Alarms, etc.)

workflow-parameters.env can be used to set the terraform destroy parameter to true.

### Docker Image

There are two applications to move data between S3 buckets. A Python Application and a Go application. The can be found in the python and go directories. 

Currently the dockerfile is set to build the python application.

### Configuration

The application will need to know the following parameters

SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/{aws-acct-number}/s3-event-queue
S3_DZ = s3-drop-zone-{unique-bucket-name}
S3_SNOWFLAKE = snowflake-drop-zone-{unique-bucket-name}

