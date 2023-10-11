output "ec2_role_arn" {
  description = "The Amazon Resource Name (ARN) of the EC2 IAM role"
  value       = aws_iam_role.ec2_role.arn
}

output "ec2_role_name" {
  description = "The name of the EC2 IAM role"
  value       = aws_iam_role.ec2_role.name
}

output "ec2_instance_profile" {
  description = "The instance profile for the EC2 launch template"
  value = aws_iam_instance_profile.ec2_data_movement_instance_profile.name
}