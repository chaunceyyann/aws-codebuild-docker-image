# Generic Lambda Module Variables

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "function_directory" {
  description = "Directory name for the function source code (optional, for organizing multiple functions)"
  type        = string
  default     = null
}

variable "handler_file" {
  description = "Name of the handler file (e.g., 'main.py')"
  type        = string
  default     = "main.py"
}

variable "handler" {
  description = "Lambda function handler (e.g., 'main.lambda_handler')"
  type        = string
  default     = "main.lambda_handler"
}

variable "runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.9"
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
}

variable "memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 128
}

variable "description" {
  description = "Description of the Lambda function"
  type        = string
  default     = ""
}

variable "build_package" {
  description = "Whether to build a deployment package with dependencies"
  type        = bool
  default     = true
}

variable "source_file" {
  description = "Path to the source file (used when build_package is false)"
  type        = string
  default     = null
}

variable "role_arn" {
  description = "ARN of the IAM role for the Lambda function (if not provided, one will be created)"
  type        = string
  default     = null
}

variable "create_role" {
  description = "Whether to create an IAM role for the Lambda function"
  type        = bool
  default     = true
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "vpc_config" {
  description = "VPC configuration for the Lambda function"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 14
}

variable "custom_policies" {
  description = "Map of custom IAM policies to attach to the Lambda role"
  type        = map(string)
  default     = {}
}

variable "event_rule" {
  description = "EventBridge rule configuration for triggering the Lambda function"
  type = object({
    description         = string
    schedule_expression = optional(string)
    event_pattern       = optional(string)
  })
  default = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
