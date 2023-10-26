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


resource "aws_iam_policy" "s3_access_policy" {
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
          var.s3_drop_zone_bucket_arn,
          var.s3_snowflake_bucket_arn
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
      }
    ]
  })
}

# Add the policies to the ECS Task Role
resource "aws_iam_policy_attachment" "ecr_access_attachment" {
  name       = "ECRAccessAttachment"
  policy_arn = aws_iam_policy.ecr_access_policy.arn
  roles      = [aws_iam_role.ecs_task_execution_role.name]
}

# Attach the AmazonECSTaskExecutionRolePolicy to the ECS task execution role
resource "aws_iam_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  name = "AmazonECSTaskExecutionRolePolicyAttachment"
  roles = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy_attachment" "s3_access_attachment" {
  name       = "S3AccessAttachment"
  policy_arn = aws_iam_policy.s3_access_policy.arn
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
      log_configuration = {
        log_driver = "awslogs"
        options = {
          "awslogs-group" = aws_cloudwatch_log_group.ecs_task_log_group.name
          "awslogs-region" = "us-east-1"  # Set your region
        }
      }
      environment = [
        { name = "SQS_QUEUE_URL", value = var.sqs_queue_url },
        { name = "S3_DZ", value = var.s3_drop_zone_bucket },
        { name = "S3_SNOWFLAKE", value = var.s3_snowflake_bucket }
      ]
      port_mappings = [
        {
          container_port = var.container_port
          host_port      = var.container_port
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


# Define Application Auto Scaling for scaling
resource "aws_appautoscaling_policy" "sqs_length_scale" {
  name               = "sqs-length-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 1  # Scale out when there is at least one message
    
    customized_metric_specification {
      metrics {
        label = "Get the queue size (the number of messages waiting to be processed)"
        id = "m1"
          
        metric_stat {
          metric {
            metric_name = "ApproximateNumberOfMessagesVisible"
            namespace = "AWS/SQS"
              
            dimensions {
              name = "QueueName"
              value = var.sqs_queue_name
            }
          }
            
          stat = "Sum"
        }
        return_data = true
      }  
    }
  }
}

# Create an AWS CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_task_log_group" {
  name              = "${var.name}-ecs_task_log_group"  # Choose a unique name for your log group
  retention_in_days = 1
}