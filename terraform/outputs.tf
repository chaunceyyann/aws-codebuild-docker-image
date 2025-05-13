output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "codebuild_project_arn" {
  description = "ARN of the CodeBuild project"
  value       = module.codebuild.project_arn
}

output "tfstate_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = module.s3_backend.bucket_name
}

output "tfstate_dynamodb_table" {
  description = "Name of the DynamoDB table for Terraform state locking"
  value       = module.s3_backend.dynamodb_table
}