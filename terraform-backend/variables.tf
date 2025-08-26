# aws-global-infra/terraform-backend/variables.tf

variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "aws-global-infra-tfstate"
}

variable "dynamodb_table" {
  description = "Name of the DynamoDB table for Terraform state locking"
  type        = string
  default     = "aws-global-infra-tfstate-lock"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}
