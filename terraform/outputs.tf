# aws-global-infra/terraform/outputs.tf

output "docker_builder_project_name" {
  description = "Name of the Docker builder CodeBuild project"
  value       = module.codebuild_docker.project_name
}

output "docker_builder_project_arn" {
  description = "ARN of the Docker builder CodeBuild project"
  value       = module.codebuild_docker.project_arn
}

# Scanner functionality is now part of the unified container-image-builder

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = module.ecr.repository_arn
}

output "base_image_version" {
  value = var.base_image_version
}

output "scanner_image_version" {
  value = var.scanner_image_version
}

# GitHub Actions Runner outputs (dynamic)
output "github_actions_runners" {
  description = "Map of all GitHub Actions runner CodeBuild projects"
  value = {
    for repo_name, runner in module.codebuild_runners : repo_name => {
      project_name = runner.project_name
      project_arn  = runner.project_arn
    }
  }
}

output "runner_project_names" {
  description = "List of all runner project names"
  value       = [for runner in module.codebuild_runners : runner.project_name]
}

output "runner_project_arns" {
  description = "List of all runner project ARNs"
  value       = [for runner in module.codebuild_runners : runner.project_arn]
}
