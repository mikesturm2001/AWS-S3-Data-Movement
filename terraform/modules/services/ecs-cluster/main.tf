# Create an IAM role for your ECS tasks
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

# Create and ECR access policy
resource "aws_iam_policy" "ecr_access_policy" {
  name        = "ECRAccessPolicy"
  description = "ECR Access Policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:BatchCheckLayerAvailability",
        ],
        Effect = "Allow",
        Resource = var.ecr_repository_arn
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
      }
    ]
  })
}

# Add the policies to the ECS Task Role
resource "aws_iam_policy_attachment" "ecr_access_attachment" {
  name       = "ECRAccessAttachment"
  policy_arn = aws_iam_policy.ecr_access_policy.arn
  roles      = [aws_iam_role.ecs_task_role.name]
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
  execution_role_arn = aws_iam_role.ecs_task_role.arn

  memory = 512   # Specify the memory setting for the container (in MiB)
  cpu = 256      # Specify the CPU setting for the container (in units)

  # Specify your container definitions with environment variables here
  container_definitions = jsonencode([
    {
      name  = "s3_data_movement"
      image = var.image

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

# Create an ECS service
resource "aws_ecs_service" "s3_data_movement_service" {
  name            = "s3-data-movement-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.s3_data_movement.arn
  launch_type     = "FARGATE"  # Or "EC2" if using EC2 launch type

  network_configuration {
    subnets = var.subnet_ids
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