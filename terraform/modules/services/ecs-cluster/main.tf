# Create an IAM role for your ECS tasks exeuction
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.name}-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Create an IAM role for ECS task
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.name}-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}


resource "aws_iam_policy" "ecr_access_policy" {
  name        = "S3AccessPolicy"
  description = "S3 Access Policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
        ],
        Effect = "Allow",
        Resource = [
          "${var.s3_drop_zone_bucket_arn}/*",
          "${var.s3_snowflake_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
        ],
        Effect = "Allow",
        Resource = var.sqs_queue_arn
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Effect = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach the AmazonECSTaskExecutionRolePolicy to the ECS task execution role
resource "aws_iam_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  name = "AmazonECSTaskExecutionRolePolicyAttachment"
  roles = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy_attachment" "s3_access_attachment" {
  name       = "S3AccessAttachment"
  policy_arn = aws_iam_policy.ecr_access_policy.arn
  roles      = [aws_iam_role.ecs_task_role.name]
}

# Create an ECS cluster
resource "aws_ecs_cluster" "cluster" {
  name = var.name
}

# Create an ECS task definition
resource "aws_ecs_task_definition" "s3_data_movement" {
  family = "s3_data_movement"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn = aws_iam_role.ecs_task_role.arn
  memory = 512   # Specify the memory setting for the container (in MiB)
  cpu = 256      # Specify the CPU setting for the container (in units)

  # Specify your container definitions with environment variables here
  container_definitions = jsonencode([
    {
      name  = "s3_data_movement"
      image = var.image
      logConfiguration  = {
        logDriver = "awslogs"
        options = {
          awslogs-group = aws_cloudwatch_log_group.ecs_task_log_group.name
          awslogs-region = "us-east-1"  # Set your region
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        { name = "SQS_QUEUE_URL", value = var.sqs_queue_url },
        { name = "S3_DZ", value = var.s3_drop_zone_bucket },
        { name = "S3_SNOWFLAKE", value = var.s3_snowflake_bucket }
      ]
      portMappings = [
        {
          containerPort = var.container_port
          hostPost      = var.container_port
        }
      ]
    }
  ])
}

resource "aws_security_group" "fargate_security_group" {
  name_prefix   = "${var.name}-fargate-sg"
  description   = "Security group for Fargate tasks"
  vpc_id        = var.vpc_id

  # Outbound rule allowing all outgoing traffic to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an ECS service
resource "aws_ecs_service" "s3_data_movement_service" {
  name            = "s3-data-movement-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.s3_data_movement.arn
  launch_type     = "FARGATE"  # Or "EC2" if using EC2 launch type

  network_configuration {
    subnets = var.subnet_ids
    security_groups = [aws_security_group.fargate_security_group.id]
  }
}

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 4
  min_capacity       = 0
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.s3_data_movement_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Create scaling step functions 
resource "aws_cloudwatch_metric_alarm" "scale_out_alarm" {
  alarm_name          = "sqs-scale-out-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "SampleCount"
  threshold           = 1  # Trigger when there's at least one message
  alarm_description   = "Trigger scaling out when there are messages in the SQS queue"
  alarm_actions       = [aws_appautoscaling_policy.scale_out_policy.arn]  # Specify the ARN of your scaling policy
  dimensions = {
    QueueName = var.sqs_queue_name
  }
}

resource "aws_cloudwatch_metric_alarm" "scale_in_alarm" {
  alarm_name          = "sqs-scale-in-alarm"
  alarm_description   = "Alarm for scaling in when the SQS queue is empty"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "SampleCount"
  threshold           = 0  # Trigger when there are no messages
  alarm_actions       = [aws_appautoscaling_policy.scale_in_policy.arn]  # Specify the ARN of your scaling policy

  dimensions = {
    QueueName = var.sqs_queue_name
  }
}

# Define Application Auto Scaling for scaling  up
resource "aws_appautoscaling_policy" "scale_out_policy" {
  name               = "scale-out-policy"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type = "ChangeInCapacity"
    cooldown        = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 1
      metric_interval_upper_bound = 15
      scaling_adjustment = 1
    }

    step_adjustment {
      metric_interval_lower_bound = 15
      scaling_adjustment = 2
    }
  }
}

# Define Application Auto Scaling for scaling  up
resource "aws_appautoscaling_policy" "scale_in_policy" {
  name               = "scale-in-policy"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type = "ChangeInCapacity"
    cooldown        = 20
    metric_aggregation_type = "Average"

    step_adjustment {
      scaling_adjustment = -1
      metric_interval_upper_bound = 0
    }
  }
}



# Create an AWS CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_task_log_group" {
  name              = "${var.name}-ecs_task_log_group"  # Choose a unique name for your log group
  retention_in_days = 1
}