# Compute Fleet Module Outputs

output "fleet_arn" {
  description = "ARN of the CodeBuild compute fleet"
  value       = aws_codebuild_fleet.main.arn
}

output "fleet_name" {
  description = "Name of the CodeBuild compute fleet"
  value       = aws_codebuild_fleet.main.name
}

output "fleet_id" {
  description = "ID of the CodeBuild compute fleet"
  value       = aws_codebuild_fleet.main.id
}

output "fleet_role_arn" {
  description = "ARN of the IAM role for the compute fleet"
  value       = aws_iam_role.fleet_role.arn
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function for fleet control"
  value       = module.fleet_controller.function_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function for fleet control"
  value       = module.fleet_controller.function_name
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard for fleet monitoring"
  value       = aws_cloudwatch_dashboard.fleet_dashboard.dashboard_name
}
