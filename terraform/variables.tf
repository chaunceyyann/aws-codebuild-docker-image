variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "ecr_repo_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "docker-image-4codebuild-repo"
}

variable "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  type        = string
  default     = "docker-image-4codebuild"
}