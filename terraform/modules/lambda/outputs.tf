# Generic Lambda Module Outputs

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.main.arn
}

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "function_invoke_arn" {
  description = "Invocation ARN of the Lambda function"
  value       = aws_lambda_function.main.invoke_arn
}

output "role_arn" {
  description = "ARN of the IAM role for the Lambda function"
  value       = var.create_role ? aws_iam_role.lambda_role[0].arn : var.role_arn
}

output "role_name" {
  description = "Name of the IAM role for the Lambda function"
  value       = var.create_role ? aws_iam_role.lambda_role[0].name : null
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.arn
}

output "event_rule_arn" {
  description = "ARN of the EventBridge rule (if created)"
  value       = var.event_rule != null ? aws_cloudwatch_event_rule.lambda_trigger[0].arn : null
}

output "event_rule_name" {
  description = "Name of the EventBridge rule (if created)"
  value       = var.event_rule != null ? aws_cloudwatch_event_rule.lambda_trigger[0].name : null
}
