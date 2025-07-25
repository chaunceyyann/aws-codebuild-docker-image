# aws-codebuild-docker-image/terraform/main.tf

module "ecr" {
  source = "./modules/ecr"

  repository_name = var.ecr_repo_name
  aws_region      = var.aws_region
}

# New ECR repository for static code scan image
module "ecr_scanner" {
  source = "./modules/ecr"

  repository_name = "code-scanner-4codebuild-repo" # Unique name for scanner repo
  aws_region      = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"

  project_name = var.docker_builder_project_name
}

# Base Docker image builder
module "codebuild_docker" {
  source                = "./modules/codebuild"
  project_name          = var.docker_builder_project_name
  aws_region            = var.aws_region
  ecr_repository_arn    = module.ecr.repository_arn
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecr_repo_url          = module.ecr.repository_url
  image_version         = var.base_image_version
  image                 = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
  source_repository_url = "https://github.com/chaunceyyann/aws-codebuild-docker-image"
  description           = "CodeBuild project for building base Docker image with development tools"
  buildspec_path        = "container-codebuild-image/buildspec.yml" # Path for Docker image build
  ecr_repo_name         = var.ecr_repo_name                         # Use the input variable for base repo name

  depends_on = [module.ecr]
}

# Static code scanner using our custom image
module "codebuild_scanner" {
  source                = "./modules/codebuild"
  project_name          = var.code_scanner_project_name
  aws_region            = var.aws_region
  ecr_repository_arn    = module.ecr.repository_arn # Use base repo ARN for permissions to pull the build environment image
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecr_repo_url          = module.ecr_scanner.repository_url # This is passed as ECR_REGISTRY for pushing the scanner image
  image_version         = var.scanner_image_version
  image                 = "${module.ecr.repository_url}:latest" # Use base image as build environment
  source_repository_url = "https://github.com/chaunceyyann/aws-codebuild-docker-image"
  description           = "CodeBuild project for running security scans using custom Docker image"
  buildspec_path        = "container-static-code-scan/buildspec.yml" # Path for scanner build
  ecr_repo_name         = "code-scanner-4codebuild-repo"             # Use the hardcoded name for scanner repo (matches input to ecr_scanner)
  environment_variables = [
    {
      name  = "SCAN_TYPE"
      value = "security"
      type  = "PLAINTEXT"
    }
  ]

  depends_on = [module.ecr, module.ecr_scanner]
}

# New CodeBuild project for YAML Validator Runner
module "codebuild_yaml_validator" {
  source                = "./modules/codebuild"
  project_name          = "codebuild-yaml-validator"
  aws_region            = var.aws_region
  ecr_repository_arn    = module.ecr.repository_arn # Use base repo ARN for permissions if needed
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecr_repo_url          = module.ecr.repository_url                                    # Not used for pushing images, just for environment if needed
  image_version         = "1.0.0"                                                      # Version for runner, can be adjusted
  image                 = "aws/codebuild/standard:7.0"                                 # Standard CodeBuild image, not using custom ECR image
  source_repository_url = "https://github.com/chaunceyyann/aws-codebuild-docker-image" # Same repo or adjust as needed
  description           = "CodeBuild project for YAML validation runner in GitHub Actions"
  buildspec_path        = "container-yaml-validator/buildspec.yml" # Path for YAML validator buildspec
  ecr_repo_name         = var.ecr_repo_name                        # Not used for pushing, just to satisfy module requirement
  environment_type      = "LINUX_CONTAINER"
  compute_type          = "BUILD_GENERAL1_MEDIUM" # Medium compute for runner tasks
  privileged_mode       = false                   # No Docker needed for this runner
  environment_variables = [
    {
      name  = "RUNNER_TYPE"
      value = "yaml-validator"
      type  = "PLAINTEXT"
    }
  ]
}
