variable "domain_name" {
  description = "Name of the CodeArtifact domain"
  type        = string
}

variable "encryption_key_arn" {
  description = "ARN of the KMS key for encryption (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
