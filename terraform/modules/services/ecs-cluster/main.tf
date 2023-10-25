# Create an IAM role for your ECS tasks
resource "aws_iam_role" "ecs-task-role" {
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

# Create an ECS cluster
resource "aws_ecs_cluster" "cluster" {
  name = var.name
}

# Create an ECS task definition
resource "aws_ecs_task_definition" "s3_data_movement" {
  family = "s3_data_movement"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn = aws_iam_role.ecs-task-role.arn

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

# Define the CloudWatch alarm
resource "aws_cloudwatch_metric_alarm" "sqs_queue_alarm" {
  alarm_name          = "sqs-queue-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 1
  metric_name        = "ApproximateNumberOfMessagesVisible"
  namespace          = "AWS/SQS"
  period             = 60  # 1 minute
  statistic          = "SampleCount"
  threshold          = 1  # When there is at least one message
  alarm_description  = "Scale ECS service based on SQS queue"

  alarm_actions = [aws_appautoscaling_policy.scale_out.arn, aws_appautoscaling_policy.scale_in.arn]

  dimensions = {
    QueueName = var.sqs_queue_name
  }
}

# Define Application Auto Scaling for scaling
resource "aws_appautoscaling_policy" "sqs_length_scale" {
  name               = "sqs-length-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.s3_data_movement_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

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
          return_data = false
        }
        
        metrics {
          label = "Get the ECS running task count (the number of currently running tasks)"
          id = "m2"

          metric_stat {
            metric {
              metric_name = "RunningTaskCount"
              namespace = "ECS/ContainerInsights"
              
              dimensions {
                name = "ClusterName"
                value = aws_ecs_cluster.cluster.name
              }
            }
            
            stat = "Average"
          }
          return_data = false
        }

        metrics {
          label = "Calculate the backlog per instance"
          id = "e1"
          expression = "m1 / m2"
          return_data = true
        }
    }
  }
}