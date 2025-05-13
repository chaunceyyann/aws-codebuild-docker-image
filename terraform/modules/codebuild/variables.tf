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