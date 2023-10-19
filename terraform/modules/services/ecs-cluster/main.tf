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

  execution_role_arn = aws_iam_role.ecs-task-role.arn

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
  task_definition = aws_ecs_task_definition.my_app.arn
  launch_type     = "FARGATE"  # Or "EC2" if using EC2 launch type

  network_configuration {
    subnets = var.subnet_ids
    security_groups = [aws_security_group.my_security_group.id]
  }
}

# Attach a load balancer if needed
resource "aws_lb" "s3_data_movement_lb" {
  name               = "s3_data_movement_lb"
  internal           = false
  load_balancer_type = "application"

  enable_deletion_protection = false

  subnets         = var.subnet_ids
  security_groups = [aws_security_group.my_security_group.id]
}

resource "aws_lb_listener" "s3_data_movement_listener" {
  load_balancer_arn = aws_lb.s3_data_movement_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response_type = "200"
  }
}