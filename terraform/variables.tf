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

variable "github_connection_arn" {
  description = "ARN of the GitHub connection"
  type        = string
}

variable "tfstate_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "docker-image-4codebuild-tfstate"
}

variable "tfstate_dynamodb_table" {
  description = "Name of the DynamoDB table for Terraform state locking"
  type        = string
  default     = "docker-image-4codebuild-tfstate-lock"
}