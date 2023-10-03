# main.tf

provider "aws" {
  region = "us-east-1" # Change to your desired AWS region
}

# Create S3 buckets
resource "aws_s3_bucket" "s3-landing-zone-12134477a" {
  bucket = "s3-landing-zone-12134477a"
  acl    = "private"
}

resource "aws_s3_bucket" "snowflake-drop-zone-12134477a" {
  bucket = "snowflake-drop-zone-12134477a"
  acl    = "private"
}

# Create SNS topic
resource "aws_sns_topic" "s3-landing-zone-12134477a_sns_topic" {
  name = "s3-landing-zone-12134477a_sns_topic"
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
            "aws:SourceArn" : aws_sns_topic.s3-landing-zone-12134477a_sns_topic.arn
          }
        }
      }
    ]
  })
}

# Subscribe the SNS topic to the SQS queue
resource "aws_sns_topic_subscription" "s3_event_subscription" {
  topic_arn = aws_sns_topic.s3-landing-zone-12134477a_sns_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.s3_event_queue.arn
}


# Create Auto Scaling Group and launch template with the IAM role
resource "aws_launch_template" "ec2_launch_template" {
  name_prefix   = "example-"
  instance_type = "t2.micro"
  image_id      = "ami-12345678" # Replace with your desired AMI ID

  iam_instance_profile {
    name = aws_iam_role.ec2_role.name
  }

  user_data = <<-EOF
            #!/bin/bash
            sudo yum update -y
            sudo yum install -y docker
            sudo systemctl start docker
            sudo systemctl enable docker
            echo 'Docker installed and started'
              
            # Pull and run your Docker container
            docker run -d --name my_container -p 80:80 your-docker-image:tag
            EOF
}

resource "aws_autoscaling_group" "s3_data_movement_asg" {
  name                      = "s3-data-movement-asg"
  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest"
  }
  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 2
}


# Create an IAM role for EC2 instances to assume
resource "aws_iam_role" "ec2_role" {
  name = "ec2-s3-access-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  # Add a lifecycle block to handle the resource if it already exists
  lifecycle {
    ignore_changes = [tags]  # Ignore changes to tags
  }
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
        Resource = [aws_s3_bucket.s3-landing-zone-12134477a.arn, aws_s3_bucket.snowflake-drop-zone-12134477a.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_permissions_attachment" {
  policy_arn = aws_iam_policy.s3_permissions_policy.arn
  role       = aws_iam_role.ec2_role.name
}