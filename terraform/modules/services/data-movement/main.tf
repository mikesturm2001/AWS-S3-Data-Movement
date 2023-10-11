# Create Auto Scaling Group and launch template with the IAM role
resource "aws_launch_template" "ec2_launch_template" {
  name_prefix   = "example-"
  instance_type = var.instance_type
  image_id      = "ami-12345678" # Replace with your desired AMI ID
  security_groups = [aws_security_group.instance.id]

  iam_instance_profile {
    name = aws_iam_role.ec2_role.name
  }

  user_data = templatefile("${path.module}/user-data.sh")

  # Required when using a launch tempate with an auto scaling group
  lifecycle {
    create_before_destroy = true
  }
}

# Get the VPC and subnets that the ASG will deploy EC2 instances into
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}


resource "aws_autoscaling_group" "s3_data_movement_asg" {
  name = "s3-data-movement-asg"
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest"
  }

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key = "Name"
    value = "terraform-asg-s3-data-movement"
    propagate_at_launch = true
  }
}

