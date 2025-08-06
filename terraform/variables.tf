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
