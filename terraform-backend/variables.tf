# aws-codebuild-docker-image/terraform-backend/variables.tf

variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "docker-image-4codebuild-tfstate"
}

variable "dynamodb_table" {
  description = "Name of the DynamoDB table for Terraform state locking"
  type        = string
  default     = "docker-image-4codebuild-tfstate-lock"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}
