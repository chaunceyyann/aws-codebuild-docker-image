# CodeBuild project
resource "aws_codebuild_project" "build" {
  name          = var.project_name
  description   = var.description
  service_role  = var.codebuild_role_arn
  build_timeout = 60

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    type                        = var.environment_type
    compute_type                = var.use_compute_fleet ? null : var.compute_type
    image                       = var.image
    image_pull_credentials_type = var.image_pull_credentials_type
    privileged_mode             = var.privileged_mode

    dynamic "environment_variable" {
      for_each = concat(
        [
          {
            name  = "AWS_DEFAULT_REGION"
            value = var.aws_region
            type  = "PLAINTEXT"
          },
          {
            name  = "ECR_REGISTRY"
            value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
            type  = "PLAINTEXT"
          },
          {
            name  = "ECR_REPOSITORY"
            value = var.ecr_repo_name
            type  = "PLAINTEXT"
          },
          {
            name  = "VERSION"
            value = var.image_version
            type  = "PLAINTEXT"
          },
          {
            name  = "AWS_ACCOUNT_ID"
            value = data.aws_caller_identity.current.account_id
            type  = "PLAINTEXT"
          },
          {
            name  = "CODEARTIFACT_DOMAIN_NAME"
            value = var.codeartifact_domain_name
            type  = "PLAINTEXT"
          },
          {
            name  = "CODEARTIFACT_REPOSITORY_NAME"
            value = var.codeartifact_repository_name
            type  = "PLAINTEXT"
          }
        ],
        var.environment_variables
      )
      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
        type  = environment_variable.value.type
      }
    }
  }

  source {
    type                = "GITHUB"
    location            = var.source_repository_url
    git_clone_depth     = 1
    report_build_status = true
    buildspec           = var.buildspec_path

    git_submodules_config {
      fetch_submodules = false
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${var.project_name}"
    }
  }

  vpc_config {
    vpc_id             = var.vpc_id
    subnets            = var.private_subnet_ids
    security_group_ids = [var.codebuild_sg_id]
  }

  tags = {
    Name    = var.project_name
    Project = "docker-image-4codebuild"
  }

  dynamic "compute_fleet" {
    for_each = var.use_compute_fleet ? [1] : []
    content {
      fleet_arn = var.compute_fleet_arn
    }
  }
}

# Webhook for automatic builds
resource "aws_codebuild_webhook" "main" {
  count = var.webhook_enabled ? 1 : 0

  project_name = aws_codebuild_project.build.name

  dynamic "filter_group" {
    for_each = length(var.webhook_filter_groups) > 0 ? var.webhook_filter_groups : []
    content {
      dynamic "filter" {
        for_each = filter_group.value
        content {
          type                    = filter.value.type
          pattern                 = filter.value.pattern
          exclude_matched_pattern = filter.value.exclude_matched_pattern
        }
      }
    }
  }
}

data "aws_caller_identity" "current" {}
