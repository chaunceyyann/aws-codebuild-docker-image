# aws-codebuild-docker-image/terraform/main.tf

module "ecr" {
  source = "./modules/ecr"

  repository_name = var.ecr_repo_name
  aws_region      = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"

  project_name = var.docker_builder_project_name
}

# Base Docker image builder
module "codebuild_docker" {
  source = "./modules/codebuild"

  project_name       = var.docker_builder_project_name
  aws_region         = var.aws_region
  ecr_repository_arn = module.ecr.repository_arn
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  ecr_repo_url       = module.ecr.repository_url

  image                 = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
  source_repository_url = "https://github.com/chaunceyyann/aws-codebuild-docker-image"
  description           = "CodeBuild project for building base Docker image with development tools"
}

# Static code scanner using our custom image
module "codebuild_scanner" {
  source = "./modules/codebuild"

  project_name       = var.code_scanner_project_name
  aws_region         = var.aws_region
  ecr_repository_arn = module.ecr.repository_arn
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  ecr_repo_url       = module.ecr.repository_url

  image                 = "${module.ecr.repository_url}:latest"
  source_repository_url = "https://github.com/chaunceyyann/aws-codebuild-docker-image"
  description           = "CodeBuild project for running security scans using custom Docker image"
  environment_variables = [
    {
      name  = "SCAN_TYPE"
      value = "security"
      type  = "PLAINTEXT"
    }
  ]
}
