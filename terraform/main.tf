# aws-codebuild-docker-image/terraform/main.tf

# Local variable for GitHub repositories that need CodeBuild runners
locals {
  github_repos = [
    {
      name        = "cyan-actions"
      owner       = "chaunceyyann"
      description = "GitHub Actions runner for cyan-actions repository"
      runner_types = ["python-app", "nodejs-api", "terraform-infra"]  # Multiple types
      branch      = "main"
    },
    {
      name        = "aws-codebuild-docker-image"
      owner       = "chaunceyyann"
      description = "GitHub Actions runner for aws-codebuild-docker-image repository"
      runner_types = ["terraform-infra"]  # Single type
      branch      = "main"
    },
    {
      name        = "comfyui-image-processing-nodes"
      owner       = "chaunceyyann"
      description = "GitHub Actions runner for comfyui-image-processing-nodes repository"
      runner_types = ["python-app"]  # Single type
      branch      = "main"
    },
    {
      name        = "BJST"
      owner       = "chaunceyyann"
      description = "GitHub Actions runner for BJST repository"
      runner_types = ["react-frontend"]  # Single type
      branch      = "main"
    },
    {
      name        = "aws-imagebuilder-image"
      owner       = "chaunceyyann"
      description = "GitHub Actions runner for aws-imagebuilder-image repository"
      runner_types = ["terraform-infra"]  # Single type
      branch      = "main"
    }
  ]
}

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
  privileged_mode       = true                                      # Enable Docker-in-Docker for building images

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
  image                 = "aws/codebuild/amazonlinux-x86_64-standard:5.0" # Use official AWS CodeBuild image
  source_repository_url = "https://github.com/chaunceyyann/aws-codebuild-docker-image"
  description           = "CodeBuild project for running security scans using custom Docker image"
  buildspec_path        = "container-static-code-scan/buildspec.yml" # Path for scanner build
  ecr_repo_name         = "code-scanner-4codebuild-repo"             # Use the hardcoded name for scanner repo (matches input to ecr_scanner)
  privileged_mode       = true                                        # Enable Docker-in-Docker for building images
  environment_variables = [
    {
      name  = "SCAN_TYPE"
      value = "security"
      type  = "PLAINTEXT"
    }
  ]

  depends_on = [module.ecr, module.ecr_scanner]
}

# Dynamic CodeBuild projects as GitHub Actions runners
# Each project is created from the local.github_repos list
module "codebuild_runners" {
  for_each = { for repo in local.github_repos : repo.name => repo }

  source                = "./modules/codebuild"
  project_name          = "${each.value.name}-runner"
  aws_region            = var.aws_region
  ecr_repository_arn    = module.ecr.repository_arn
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecr_repo_url          = module.ecr.repository_url
  image_version         = "1.0.0"
  image                 = "${module.ecr.repository_url}:latest"
  source_repository_url = "https://github.com/${each.value.owner}/${each.value.name}"
  description           = each.value.description
  buildspec_path        = "buildspecs/runner.yml"
  ecr_repo_name         = var.ecr_repo_name

  # GitHub repository configuration
  github_owner                 = each.value.owner
  github_repo                  = each.value.name
  github_branch                = each.value.branch

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
  compute_type     = "BUILD_GENERAL1_MEDIUM"
  privileged_mode  = false

  environment_variables = [
    {
      name  = "RUNNER_TYPES"
      value = join(",", each.value.runner_types)
      type  = "PLAINTEXT"
    },
    {
      name  = "PRIMARY_RUNNER_TYPE"
      value = each.value.runner_types[0]
      type  = "PLAINTEXT"
    }
  ]

  depends_on = [module.ecr]
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
