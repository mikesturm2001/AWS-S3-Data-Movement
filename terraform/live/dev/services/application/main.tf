# Set up back end state
terraform {
  backend "s3" {
    bucket         = "terraform-data-movement-state-1247"
    key            = "dev/services/application/terraform.tfstate"
    region         = "us-east-1"

    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}

# Fetch EC2 Role information
data "terraform_remote_state" "ec2_role" {
  backend = "s3"
  config = {
    bucket = "terraform-data-movement-state-1247"
    key    = "global/iam/terraform.tfstate"
    region = "us-east-1"
  }
}

# Fetch latest Docker image
data "terraform_remote_state" "aws_ecr_repository" {
  backend = "s3"
  config = {
    bucket = "terraform-data-movement-state-1247"
    key = "global/ecr/terraform.tfstate"
    region = "us-east-1"
  }
}

# Fetch VPC information
data "terraform_remote_state" "data_movement_vpc" {
  backend = "s3"
    config = {
    bucket = "terraform-data-movement-state-1247"
    key = "global/vpc/terraform.tfstate"
    region = "us-east-1"
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

data "aws_ecr_image" "app_image" {
  repository_name = data.terraform_remote_state.aws_ecr_repository.outputs.ecr_repository_name
  image_tag = "latest"
}

# Import main Python Application
module "ecs-cluster" {
  source = "../../../../modules/services/ecs-cluster"

  name = "data-movement"
  min_size = var.min_size
  max_size = var.max_size
  desired_size = 0
  subnet_ids = data.terraform_remote_state.data_movement_vpc.outputs.private_subnet_ids
  instance_types = [ "t3.small" ]
  image = "157099750066.dkr.ecr.us-east-1.amazonaws.com/aws_s3_data_movement_repository:latest"
  s3_drop_zone_bucket = var.s3_drop_zone_bucket
  s3_snowflake_bucket = var.s3_snowflake_bucket
  sqs_queue_url = aws_sqs_queue.s3_event_queue.id
  sqs_queue_name = aws_sqs_queue.s3_event_queue.name
  replicas = 0
  container_port = 5000

  depends_on = [ aws_sqs_queue.s3_event_queue ]
}

# Import main Python Application
#module "eks_cluster" {
#  source = "../../../../modules/services/eks-cluster"

#  name = "data-movement-eks-cluster"
#  min_size = 1
#  max_size = 2
#  desired_size = 1
#  subnet_ids = data.terraform_remote_state.data_movement_vpc.outputs.private_subnet_ids
#  instance_types = ["t3.small"]
#}

#provider "kubernetes" {
#  host = module.eks_cluster.cluster_endpoint
#  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority[0].data)
#  token = data.aws_eks_cluster_auth.cluster.token
#}

#data "aws_eks_cluster_auth" "cluster" {
#  name = module.eks_cluster.cluster_name
#}

#module "data-movement" {
#  source = "../../../../modules/services/k8s-app"
#  name = "data-movement"
# "${var.aws_account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.project_name}:${var.latest-Tag}"
#  image = "157099750066.dkr.ecr.us-east-1.amazonaws.com/aws_s3_data_movement_repository:latest"
#  replicas = 2
#  container_port = 5000

#  environment_variables = {
#    PROVIDER = "Terraform"
#  }

  # Only deploy the app after the cluster has been deployed
#  depends_on = [module.eks_cluster]
#}

# Create SNS topic
resource "aws_sns_topic" "s3-landing-zone-sns-topic" {
  name = "s3-landing-zone-sns-topic"
  fifo_topic = false
}

# Create EventBridge rule to read S3 put notifications
resource "aws_cloudwatch_event_rule" "s3_event_rule" {
  name        = "landing-zone-s3-event-rule"
  description = "Rule for S3 landing zone bucket Put events"

  event_pattern = jsonencode({
    source      = ["aws.s3"],
    detail-type = ["Object Created"],
    detail      = {
      bucket = {
        name = [var.s3_drop_zone_bucket]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "target" {
  rule      = aws_cloudwatch_event_rule.s3_event_rule.name
  target_id = "sns-target"
  
  # Specify your target action here (e.g., SNS topic, Lambda function, etc.)
  # Example: SNS Topic
  arn = aws_sns_topic.s3-landing-zone-sns-topic.arn
}

# Create an SQS queue
resource "aws_sqs_queue" "s3_event_queue" {
  name                      = "s3-event-queue"
  fifo_queue                = false
  content_based_deduplication = false
}

# Define a policy for allowing SNS to publish to the SQS queue
resource "aws_sqs_queue_policy" "s3_event_queue_policy" {
  queue_url = aws_sqs_queue.s3_event_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "s3_event_queue_policy",
    Statement = [
      {
        Sid       = "AllowSNSToPublish",
        Effect    = "Allow",
        Principal = "*",
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.s3_event_queue.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" : aws_sns_topic.s3-landing-zone-sns-topic.arn
          }
        }
      }
    ]
  })
}

# Subscribe the SNS topic to the SQS queue
resource "aws_sns_topic_subscription" "s3_event_subscription" {
  topic_arn = aws_sns_topic.s3-landing-zone-sns-topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.s3_event_queue.arn
}
