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
  description = "Name of the container image builder CodeBuild project"
  type        = string
  default     = "container-image-builder"
}

# Scanner functionality is handled by the container-image-builder project

variable "base_image_version" {
  description = "Version of the base Docker image"
  type        = string
  default     = "1.0.0"
}

variable "scanner_image_version" {
  description = "Version of the scanner Docker image"
  type        = string
  default     = "1.0.0"
}

variable "codeartifact_domain_name" {
  description = "Name of the CodeArtifact domain"
  type        = string
  default     = "security-tools-domain"
}

variable "codeartifact_encryption_key_arn" {
  description = "ARN of the KMS key for CodeArtifact encryption (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Compute Fleet Configuration
variable "fleet_base_capacity" {
  description = "Base capacity for the CodeBuild compute fleet"
  type        = number
  default     = 1
}

variable "fleet_target_capacity" {
  description = "Target capacity for the CodeBuild compute fleet"
  type        = number
  default     = 2
}

variable "fleet_max_capacity" {
  description = "Maximum capacity for the CodeBuild compute fleet"
  type        = number
  default     = 10
}

variable "fleet_min_capacity" {
  description = "Minimum capacity for the CodeBuild compute fleet"
  type        = number
  default     = 0
}

variable "enable_fleet_for_runners" {
  description = "Enable compute fleet for GitHub Actions runners"
  type        = bool
  default     = true
}
