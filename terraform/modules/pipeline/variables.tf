variable "pipeline_name" {
  description = "Name of the CodePipeline"
  type        = string
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
}

variable "github_repo_owner" {
  description = "GitHub repository owner (username or organization)"
  type        = string
}

variable "github_repo_name" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch to source from"
  type        = string
}

variable "github_connection_arn" {
  description = "ARN of the CodeStar Connections for GitHub"
  type        = string
  default     = ""
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  type        = string
}