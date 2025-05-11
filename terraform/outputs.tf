output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "pipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = module.pipeline.pipeline_arn
}