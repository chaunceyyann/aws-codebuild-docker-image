# aws-codebuild-docker-image/terraform/main.tf

module "ecr" {
  source = "./modules/ecr"

  repository_name = var.ecr_repo_name
  aws_region      = var.aws_region
}

module "codebuild" {
  source = "./modules/codebuild"

  project_name       = var.codebuild_project_name
  aws_region         = var.aws_region
  ecr_repository_arn = module.ecr.repository_arn
}