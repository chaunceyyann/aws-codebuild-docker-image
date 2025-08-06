# aws-codebuild-docker-image/terraform/locals.tf

# Local variable for GitHub repositories that need CodeBuild runners
locals {
  github_repos = [
    {
      name        = "cyan-actions"
      owner       = "chaunceyyann"
      description = "GitHub Actions runner for cyan-actions repository"
      branch      = "main"
    },
    {
      name        = "aws-codebuild-docker-image"
      owner       = "chaunceyyann"
      description = "GitHub Actions runner for aws-codebuild-docker-image repository"
      branch      = "main"
    },
    {
      name        = "comfyui-image-processing-nodes"
      owner       = "chaunceyyann"
      description = "GitHub Actions runner for comfyui-image-processing-nodes repository"
      branch      = "main"
    },
    {
      name        = "BJST"
      owner       = "chaunceyyann"
      description = "GitHub Actions runner for BJST repository"
      branch      = "main"
    },
    {
      name        = "aws-imagebuilder-image"
      owner       = "chaunceyyann"
      description = "GitHub Actions runner for aws-imagebuilder-image repository"
      branch      = "main"
    }
  ]
}
