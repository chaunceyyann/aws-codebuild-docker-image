# aws-codebuild-docker-image/terraform/outputs.tf

output "docker_builder_project_name" {
  description = "Name of the Docker builder CodeBuild project"
  value       = module.codebuild_docker.project_name
}

output "docker_builder_project_arn" {
  description = "ARN of the Docker builder CodeBuild project"
  value       = module.codebuild_docker.project_arn
}

output "code_scanner_project_name" {
  description = "Name of the code scanner CodeBuild project"
  value       = module.codebuild_scanner.project_name
}

output "code_scanner_project_arn" {
  description = "ARN of the code scanner CodeBuild project"
  value       = module.codebuild_scanner.project_arn
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = module.ecr.repository_arn
}