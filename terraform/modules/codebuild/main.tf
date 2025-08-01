# IAM role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role"

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
      }
    ]
  })
}

# Security group for CodeBuild
resource "aws_security_group" "codebuild_sg" {
  name        = "${var.project_name}-codebuild-sg"
  description = "Security group for CodeBuild project ${var.project_name}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-codebuild-sg"
  }
}

# CodeBuild project
resource "aws_codebuild_project" "build" {
  name          = var.project_name
  description   = var.description
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 60

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    type                        = var.environment_type
    compute_type                = var.compute_type
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

    # Note: Authentication is handled via webhook configuration
    # OAuth token is stored in Secrets Manager for webhook access
  }

  # Note: GitHub Actions runner configuration is handled via webhooks and IAM permissions
  # The CodeBuild project will be available as a runner when webhook is enabled

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${var.project_name}"
    }
  }

  vpc_config {
    vpc_id             = var.vpc_id
    subnets            = var.private_subnet_ids
    security_group_ids = [aws_security_group.codebuild_sg.id]
  }

  tags = {
    Name    = var.project_name
    Project = "docker-image-4codebuild"
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

# Reference an existing secret in Secrets Manager
data "aws_secretsmanager_secret" "github_token" {
  name = "codebuild/github-oauth-token"
}

# Grant CodeBuild role access to Secrets Manager
resource "aws_iam_role_policy" "codebuild_secrets_policy" {
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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

data "aws_caller_identity" "current" {}
