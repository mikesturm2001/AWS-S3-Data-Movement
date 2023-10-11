output "ec2_role_arn" {
  description = "The Amazon Resource Name (ARN) of the EC2 IAM role"
  value       = aws_iam_role.ec2_role.arn
}

output "ec2_role_name" {
  description = "The name of the EC2 IAM role"
  value       = aws_iam_role.ec2_role.name
}