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

# Import main Python Application
module "data-movement" {
  source = "../../../../modules/services/data-movement"
  cluster_name = "S3-to-S3"
  instance_type = "t2.micro"
  ec2_role_name = data.terraform_remote_state.ec2_role.outputs.ec2_role_name
  ec2_role_arn = data.terraform_remote_state.ec2_role.outputs.ec2_role_arn
  ec2_instance_profile = data.terraform_remote_state.ec2_role.outputs.ec2_instance_profile
  min_size = 0
  max_size = 2
}


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
    detail_type = ["AWS API Call via CloudTrail"],
    detail      = {
      eventSource = ["s3.amazonaws.com"],
      eventName   = ["PutObject", "CopyObject"]  # Add other events as needed
      requestParameters = {
        bucketName = ["s3-landing-zone-12134477a"]
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