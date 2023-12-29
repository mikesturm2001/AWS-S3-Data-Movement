# Set up AWS via Terraform and Github actions

## Prerequisites 

### AWS

Create an AWS github deploy user with all the necessary policy permissions to create AWS Infrastructure

AWS User
Attach Permission Policies

### Github

Configure Github actions to deploy to AWS via your AWS github deploy user

Github -> Settings -> Secrets and variables -> Actions

Add the following Repository secrets

`AWS_ACCESS_KEY_ID`     - Key ID for your AWS user
`AWS_SECRET_ACCESS_KEY` - Access Key for you AWS user
`AWS_ACCOUNT_ID`        - Account ID of your AWS account
`AWS_ECR_REPO`          - The ECR registry ex (aws_account_id.dkr.ecr.us-west-2.amazonaws.com)
`AWS_REGION`            - The AWS Region your app will be deployed to

### Actions

Inside of Github go to the actions tab and manually run the deployments. Deployments should be run in the following order

1. terraform_state_init.yaml    - This will create the AWS terraform backend
2. aws_ecr_creation.yaml        - This will create the AWS ECR repository for storing application images
3. ecr.yaml                     - This will create the Docker Image and deploy it to ECR
4. aws_iam.yaml                 - This will create all IAM users for the application
5. aws_s3_buckets.yaml          - This will create the AWS S3 buckets for moving data to and from
6. aws_vpc_creation.yaml        - This will create the VPC for the application
7. aws_application_deploy.yaml  - This will deploy all the infrastructure to AWS to run the application

### Deleting Application

When no longer needed set all the values in workflow-parameters.env to true and re run all actions. Terraform destroy commands will be run.