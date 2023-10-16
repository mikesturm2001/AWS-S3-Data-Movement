output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.aws_s3_data_movement_repository.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.aws_s3_data_movement_repository.name
}

output "ecr_repository_id" {
  description = "ID of the ECR repository"
  value       = aws_ecr_repository.aws_s3_data_movement_repository.id
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.aws_s3_data_movement_repository.arn
}
