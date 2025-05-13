variable "project_name" {
  description = "Name of the CodeBuild project"
  type        = string
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "ecr_repo_url" {
  description = "URL of the ECR repository"
  type        = string
}