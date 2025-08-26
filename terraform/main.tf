# aws-global-infra/terraform/main.tf

# This file contains the main module calls for the CodeBuild infrastructure

# Compute Fleet for CodeBuild runners
module "compute_fleet" {
  source = "./modules/compute-fleet"

  fleet_name         = "codebuild-runners-fleet"
  base_capacity      = var.fleet_base_capacity
  target_capacity    = var.fleet_target_capacity
  max_capacity       = var.fleet_max_capacity
  min_capacity       = var.fleet_min_capacity
  environment_type   = "LINUX_CONTAINER"
  compute_type       = "BUILD_GENERAL1_SMALL"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_id  = aws_security_group.codebuild_sg.id
  aws_region         = var.aws_region
  tags               = var.tags
  enable_scheduled_control = true
  schedule_expression = "cron(0 8,12,16,20 * * ? *)"  # 8 AM, 12 PM, 4 PM, 8 PM UTC daily

  depends_on = [module.vpc, aws_security_group.codebuild_sg]
}

# CodeArtifact module for package management
module "codeartifact" {
  source = "./modules/codeartifact"

  domain_name = var.codeartifact_domain_name
  encryption_key_arn = var.codeartifact_encryption_key_arn
  tags = var.tags
}

module "ecr" {
  source = "./modules/ecr"

  repository_name = var.ecr_repo_name
  aws_region      = var.aws_region
}

# ECR repository for static code scanner images
module "ecr_scanner" {
  source = "./modules/ecr"

  repository_name = "code-scanner-4codebuild-repo"
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
  source_repository_url = "https://github.com/chaunceyyann/aws-global-infra"
  description           = "CodeBuild project for building base Docker image with development tools"
  buildspec_path        = "container-codebuild-image/buildspec.yml" # Path for Docker image build
  ecr_repo_name         = var.ecr_repo_name                         # Use the input variable for base repo name
  privileged_mode       = true                                      # Enable Docker-in-Docker for building images
  codebuild_role_arn    = aws_iam_role.codebuild_role.arn
  codebuild_sg_id       = aws_security_group.codebuild_sg.id
  codeartifact_domain_name = module.codeartifact.domain_name
  codeartifact_repository_name = module.codeartifact.generic_repository_name

  # Additional environment variables for scanner ECR repository
  environment_variables = [
    {
      name  = "SCANNER_ECR_REPO_URL"
      value = module.ecr_scanner.repository_url
      type  = "PLAINTEXT"
    }
  ]

  depends_on = [module.ecr, module.ecr_scanner, module.codeartifact]
}

# Note: Scanner functionality is now handled by the unified container-image-builder
# The builder can use different buildspecs for different image types

# Dynamic CodeBuild projects as GitHub Actions runners
# Each project is created from the local.github_repos list
module "codebuild_runners" {
  for_each = { for repo in local.github_repos : repo.name => repo }

  source                = "./modules/codebuild"
  project_name          = "runner-${each.value.name}"
  aws_region            = var.aws_region
  ecr_repository_arn    = module.ecr.repository_arn
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecr_repo_url          = module.ecr.repository_url
  image_version         = "1.0.0"
  image                 = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
  source_repository_url = "https://github.com/${each.value.owner}/${each.value.name}"
  description           = each.value.description
  buildspec_path        = "buildspecs/gha_buildspec_minimal.yml"
  ecr_repo_name         = var.ecr_repo_name
  codebuild_role_arn    = aws_iam_role.codebuild_role.arn
  codebuild_sg_id       = aws_security_group.codebuild_sg.id

  # Enable webhook for automatic builds
  webhook_enabled = true
  webhook_filter_groups = [
    [
      {
        type                 = "EVENT"
        pattern              = "WORKFLOW_JOB_QUEUED"
        exclude_matched_pattern = false
      }
    ]
  ]

  environment_type = "LINUX_CONTAINER"
                compute_type     = "BUILD_GENERAL1_SMALL"
  privileged_mode  = false

  # Use compute fleet if enabled
  use_compute_fleet   = var.enable_fleet_for_runners
  compute_fleet_arn   = var.enable_fleet_for_runners ? module.compute_fleet.fleet_arn : null

  environment_variables = []

  depends_on = [module.ecr, module.compute_fleet]
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
  source_repository_url = "https://github.com/chaunceyyann/aws-global-infra" # Same repo or adjust as needed
  description           = "CodeBuild project for YAML validation runner in GitHub Actions"
  buildspec_path        = "container-yaml-validator/buildspec.yml" # Path for YAML validator buildspec
  ecr_repo_name         = var.ecr_repo_name                        # Not used for pushing, just to satisfy module requirement
  environment_type      = "LINUX_CONTAINER"
                compute_type          = "BUILD_GENERAL1_SMALL" # Small compute for runner tasks
  privileged_mode       = false                   # No Docker needed for this runner
  codebuild_role_arn    = aws_iam_role.codebuild_role.arn
  codebuild_sg_id       = aws_security_group.codebuild_sg.id
  environment_variables = [
    {
      name  = "RUNNER_TYPE"
      value = "yaml-validator"
      type  = "PLAINTEXT"
    }
  ]
}
