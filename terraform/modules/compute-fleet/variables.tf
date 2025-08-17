# Compute Fleet Module Variables

variable "fleet_name" {
  description = "Name of the CodeBuild compute fleet"
  type        = string
}

variable "base_capacity" {
  description = "Base capacity for the compute fleet"
  type        = number
  default     = 1
}

variable "environment_type" {
  description = "Environment type for the compute fleet"
  type        = string
  default     = "LINUX_CONTAINER"
}

variable "compute_type" {
  description = "Compute type for the compute fleet"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "vpc_id" {
  description = "VPC ID for the compute fleet"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the compute fleet"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for the compute fleet"
  type        = string
}

variable "target_capacity" {
  description = "Target capacity for the compute fleet"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum capacity for the compute fleet"
  type        = number
  default     = 10
}

variable "min_capacity" {
  description = "Minimum capacity for the compute fleet"
  type        = number
  default     = 0
}

variable "scale_in_cooldown" {
  description = "Scale in cooldown period in seconds"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Scale out cooldown period in seconds"
  type        = number
  default     = 60
}

variable "artifacts_bucket_arn" {
  description = "ARN of the S3 bucket for artifacts (use '*' for all buckets)"
  type        = string
  default     = "*"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_scheduled_control" {
  description = "Enable scheduled control for the fleet"
  type        = bool
  default     = false
}

variable "schedule_expression" {
  description = "Schedule expression for fleet control (cron format)"
  type        = string
  default     = "cron(0 8 * * ? *)"  # 8 AM UTC daily
}

variable "aws_region" {
  description = "AWS region for the fleet"
  type        = string
}
