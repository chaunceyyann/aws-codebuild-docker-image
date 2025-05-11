variable "ecr_repo_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "docker-image-4codebuild-repo"
}

variable "aws_region" {
  description = "AWS region for the ECR repository"
  type        = string
  default     = "us-east-1"
}

variable "pipeline_name" {
  description = "Name of the CodePipeline"
  type        = string
  default     = "docker-image-4codebuild-pipeline"
}

variable "github_repo_owner" {
  description = "GitHub repository owner (username or organization)"
  type        = string
}

variable "github_repo_name" {
  description = "GitHub repository name"
  type        = string
  default     = "aws-codebuild-docker-image"
}

variable "github_branch" {
  description = "GitHub branch to source from"
  type        = string
  default     = "master"
}