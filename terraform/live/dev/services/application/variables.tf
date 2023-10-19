variable "s3_drop_zone_bucket" {
  description = "S3 bucket where files are dropped"
  type = string
}

variable "s3_snowflake_bucket" {
    description = "S3 bucket to load files to Snowflake"
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
