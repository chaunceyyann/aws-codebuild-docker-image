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
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  ecr_repo_url      = module.ecr.repository_url
}