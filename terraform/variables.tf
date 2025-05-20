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

variable "docker_builder_project_name" {
  description = "Name of the Docker builder CodeBuild project"
  type        = string
  default     = "docker-image-4codebuild"
}

variable "code_scanner_project_name" {
  description = "Name of the code scanner CodeBuild project"
  type        = string
  default     = "code-scanner-4codebuild"
}