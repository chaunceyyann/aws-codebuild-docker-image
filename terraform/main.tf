module "ecr" {
  source          = "./modules/ecr"
  repository_name = var.ecr_repo_name
  aws_region      = var.aws_region
}

module "pipeline" {
  source = "./modules/pipeline"

  pipeline_name      = var.pipeline_name
  aws_region         = var.aws_region
  github_repo_owner  = var.github_repo_owner
  github_repo_name   = var.github_repo_name
  github_branch      = var.github_branch
  ecr_repository_arn = module.ecr.repository_arn
}