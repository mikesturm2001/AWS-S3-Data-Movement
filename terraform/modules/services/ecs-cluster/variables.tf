variable "name" {
  description = "The name to use for the EKS cluster"
  type = string
}

variable "min_size" {
  description = "Minimum number of nodes to have in the EKS cluster"
  type = number
}

variable "max_size" {
  description = "Maximum number of nodes to have in the EKS cluster"
  type = number
}

variable "desired_size" {
  description = "Desired number of nodes to have in the EKS cluster"
  type = number
}

variable "instance_types" {
  description = "The types of EC2 instances to run in the node group"
  type = list(string)
}

variable "subnet_ids" {
  description = "The IDs of the private subnets"
  type = list(string)
}

variable "image" {
    description = "The Docker image to run"
    type = string
}

variable "container_port" {
    description = "The port the Docker image listens on"
    type = number
}

variable "replicas" {
    description = "How many replicas to run"
    type = number
}

variable "environment_variables" {
    description = "Environment variables to set for the app"
    type = map(string)
    default = {}
}

variable "sqs_queue_name" {
  description = "SQS Queue name"
  type = string
}

variable "sqs_queue_url" {
  description = "SQS Queue for S3 put notifications"
  type = string
}

variable "s3_drop_zone_bucket" {
  description = "S3 bucket where files are dropped"
  type = string
}

variable "s3_snowflake_bucket" {
    description = "S3 bucket to load files to Snowflake"
    type = string
}