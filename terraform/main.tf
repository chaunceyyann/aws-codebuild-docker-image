# aws-codebuild-docker-image/terraform/main.tf

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

# Shared resources for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "shared-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchDeleteImage",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = [
          "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/docker-image-4codebuild-repo",
          "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/code-scanner-4codebuild-repo",
          "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:AttachNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = data.aws_secretsmanager_secret.github_token.arn
      }
    ]
  })
}

resource "aws_security_group" "codebuild_sg" {
  name        = "shared-codebuild-sg"
  description = "Shared security group for all CodeBuild projects"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "shared-codebuild-sg"
  }
}

data "aws_secretsmanager_secret" "github_token" {
  name = "codebuild/github-oauth-token"
}

data "aws_caller_identity" "current" {}

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
  codebuild_role_arn    = aws_iam_role.codebuild_role.arn
  codebuild_sg_id       = aws_security_group.codebuild_sg.id

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
  codebuild_role_arn    = aws_iam_role.codebuild_role.arn
  codebuild_sg_id       = aws_security_group.codebuild_sg.id
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
  compute_type     = "BUILD_GENERAL1_MEDIUM"
  privileged_mode  = false

  environment_variables = []

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
