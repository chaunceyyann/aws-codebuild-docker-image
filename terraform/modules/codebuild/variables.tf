# terraform/modules/codebuild/variables.tf

variable "project_name" {
  description = "The name of the CodeBuild project."
  type        = string
}

variable "description" {
  description = "A description of the CodeBuild project."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "The AWS region for the CodeBuild project."
  type        = string
}

variable "ecr_repository_arn" {
  description = "The ARN of the ECR repository."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs."
  type        = list(string)
}

variable "ecr_repo_url" {
  description = "The URL of the ECR repository."
  type        = string
}

variable "image_version" {
  description = "The version of the Docker image."
  type        = string
}

variable "image" {
  description = "The Docker image to use for the build environment."
  type        = string
  default     = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
}

variable "source_repository_url" {
  description = "The URL of the source repository."
  type        = string
}

variable "buildspec_path" {
  description = "The path to the buildspec file."
  type        = string
  default     = "buildspecs/gha_buildspec_minimal.yml"
}

variable "ecr_repo_name" {
  description = "The name of the ECR repository."
  type        = string
}

variable "privileged_mode" {
  description = "Whether to enable privileged mode for the build container."
  type        = bool
  default     = false
}

variable "environment_variables" {
  description = "A list of environment variables for the build project."
  type        = list(object({
    name  = string
    value = string
    type  = string
  }))
  default = []
}

variable "webhook_enabled" {
  description = "Whether to enable the webhook for the CodeBuild project."
  type        = bool
  default     = false
}

variable "webhook_filter_groups" {
  description = "A list of filter groups for the webhook."
  type        = any
  default     = []
}

variable "environment_type" {
  description = "The type of environment for the CodeBuild project."
  type        = string
  default     = "LINUX_CONTAINER"
}

variable "compute_type" {
  description = "The compute type for the CodeBuild project."
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "image_pull_credentials_type" {
  description = "The type of credentials to use to pull the image."
  type        = string
  default     = "CODEBUILD"
}

variable "codebuild_role_arn" {
  description = "The ARN of the IAM role for CodeBuild."
  type        = string
}

variable "codebuild_sg_id" {
  description = "The ID of the security group for CodeBuild."
  type        = string
}

variable "codeartifact_domain_name" {
  description = "The name of the CodeArtifact domain."
  type        = string
  default     = "security-tools-domain"
}

variable "codeartifact_repository_name" {
  description = "The name of the CodeArtifact repository for binary packages."
  type        = string
  default     = "generic-store"
}
