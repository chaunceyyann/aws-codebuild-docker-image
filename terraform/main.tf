module "ecr" {
  source          = "./modules/ecr"
  repository_name = var.ecr_repo_name
  aws_region      = var.aws_region
}

module "codebuild" {
  source = "./modules/codebuild"

  project_name       = var.codebuild_project_name
  aws_region         = var.aws_region
  ecr_repository_arn = module.ecr.repository_arn
}

module "s3_backend" {
  source = "./modules/s3-backend"

  bucket_name     = var.tfstate_bucket_name
  dynamodb_table  = var.tfstate_dynamodb_table
  aws_region      = var.aws_region
}