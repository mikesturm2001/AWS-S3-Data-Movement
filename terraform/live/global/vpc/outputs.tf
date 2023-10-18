output "vpc_id" {
  value = aws_vpc.data_movement_vpc.id
  description = "The ID of the VPC"
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnet[*].id
  description = "The ID of the public subnet"
}

output "private_subnet_ids" {
  value = [for subnet in aws_subnet.private_subnets : subnet.id]
  description = "The IDs of the private subnets"
}