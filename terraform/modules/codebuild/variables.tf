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

variable "environment_type" {
  description = "Type of build environment"
  type        = string
  default     = "LINUX_CONTAINER"
}

variable "compute_type" {
  description = "Information about the compute resources the build project will use"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "image" {
  description = "Docker image to use for this build project"
  type        = string
}

variable "image_pull_credentials_type" {
  description = "Type of credentials AWS CodeBuild uses to pull images"
  type        = string
  default     = "CODEBUILD"
}

variable "privileged_mode" {
  description = "If true, enables running the Docker daemon inside a Docker container"
  type        = bool
  default     = true
}

variable "environment_variables" {
  description = "Additional environment variables to add to the build environment"
  type = list(object({
    name  = string
    value = string
    type  = string
  }))
  default = []
}

variable "source_repository_url" {
  description = "URL of the GitHub repository"
  type        = string
}

variable "description" {
  description = "Description of the CodeBuild project"
  type        = string
  default     = "CodeBuild project"
}

variable "image_version" {
  description = "Version of the Docker image to build"
  type        = string
}

variable "ecr_repo_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "docker-image-4codebuild-repo"
}

variable "buildspec_path" {
  description = "Path to the buildspec file relative to the Terraform root or module directory"
  type        = string
  default     = "container-codebuild-image/buildspec.yml" # Default for Docker image build
}
