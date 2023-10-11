module "data-movement" {
  source = "../../modules/services/data-movement"

  instance_type = "t2.micro"
  min_size = 0
  max_size = 2
}

# Attach an inline policy to the IAM role to grant S3 permissions
resource "aws_iam_policy" "s3_permissions_policy" {
  name        = "s3-access-policy"
  description = "Policy to access S3 buckets"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
        Effect   = "Allow",
        Resource = [aws_s3_bucket.s3-landing-zone.arn, aws_s3_bucket.snowflake-drop-zone-12134477a.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_permissions_attachment" {
  policy_arn = aws_iam_policy.s3_permissions_policy.arn
  role       = aws_iam_role.ec2_role.name
}

# Fetch the S3 bucket IDs from the remote state
data "terraform_remote_state" "remote" {
  backend = "s3"
  config = {
    bucket         = "terraform-data-movement-state-1247"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
  }
}

# Create SNS topic
resource "aws_sns_topic" "s3-landing-zone_sns_topic" {
  name = "s3-landing-zone_sns_topic"

  # Explicitly depend on the creation of the S3 buckets
  depends_on = ["${data.terraform_remote_state.remote.s3_drop_zone_bucket_id}", 
                "${data.terraform_remote_state.remote.snowflake_drop_zone_bucket_id}"]
}

# Create EventBridge rule to read S3 put notifications
resource "aws_cloudwatch_event_rule" "s3_event_rule" {
  name        = "landing-zone-s3-event-rule"
  description = "Rule for S3 landing zone bucket Put events"
  # Explicitly depend on the creation of the S3 buckets
  depends_on = [aws_s3_bucket.s3-landing-zone, aws_s3_bucket.snowflake-drop-zone-12134477a]
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
  arn = aws_sns_topic.s3-landing-zone-12134477a_sns_topic.arn
}

# Create an SQS FIFO queue
resource "aws_sqs_queue" "s3_event_queue" {
  name                      = "s3-event-queue.fifo"
  fifo_queue                = true
  content_based_deduplication = true
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
            "aws:SourceArn" : aws_sns_topic.s3-landing-zone_sns_topic.arn
          }
        }
      }
    ]
  })
}

# Subscribe the SNS topic to the SQS queue
resource "aws_sns_topic_subscription" "s3_event_subscription" {
  topic_arn = aws_sns_topic.s3-landing-zone_sns_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.s3_event_queue.arn
}