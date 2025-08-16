# CodeArtifact Domain
resource "aws_codeartifact_domain" "main" {
  domain = var.domain_name
  encryption_key = var.encryption_key_arn

  tags = var.tags
}



# npm repository for Node.js packages
resource "aws_codeartifact_repository" "npm" {
  repository = "npm-store"
  domain = aws_codeartifact_domain.main.domain
  description = "npm package repository for development tools"

  external_connections {
    external_connection_name = "public:npmjs"
  }

  tags = var.tags
}

# pip repository for Python packages
resource "aws_codeartifact_repository" "pip" {
  repository = "pip-store"
  domain = aws_codeartifact_domain.main.domain
  description = "pip package repository for development tools"

  external_connections {
    external_connection_name = "public:pypi"
  }

  tags = var.tags
}

# Maven repository for Java-based tools
resource "aws_codeartifact_repository" "maven" {
  repository = "maven-store"
  domain = aws_codeartifact_domain.main.domain
  description = "Maven repository for Java-based development tools"

  external_connections {
    external_connection_name = "public:maven-central"
  }

  tags = var.tags
}

# Generic repository for binary packages (trivy, grype, etc.)
resource "aws_codeartifact_repository" "generic" {
  repository = "generic-store"
  domain = aws_codeartifact_domain.main.domain
  description = "Generic repository for binary packages and tools"

  tags = var.tags
}

# Repository for internal packages
resource "aws_codeartifact_repository" "internal" {
  repository = "internal-store"
  domain = aws_codeartifact_domain.main.domain
  description = "Internal repository for custom packages"

  upstream {
    repository_name = aws_codeartifact_repository.npm.repository
  }

  upstream {
    repository_name = aws_codeartifact_repository.pip.repository
  }

  upstream {
    repository_name = aws_codeartifact_repository.maven.repository
  }

  upstream {
    repository_name = aws_codeartifact_repository.generic.repository
  }

  tags = var.tags
}

# IAM policy for CodeArtifact access
resource "aws_iam_policy" "codeartifact_access" {
  name = "${var.domain_name}-codeartifact-access"
  description = "Policy for CodeArtifact access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codeartifact:GetAuthorizationToken",
          "codeartifact:GetRepositoryEndpoint",
          "codeartifact:ReadFromRepository",
          "codeartifact:GetPackageVersionAsset",
          "codeartifact:GetPackageVersion",
          "codeartifact:ListPackageVersions",
          "codeartifact:ListPackages",
          "codeartifact:DescribePackage",
          "codeartifact:DescribePackageVersion",
          "codeartifact:DescribeRepository",
          "codeartifact:DescribeDomain",
          "codeartifact:ListRepositories",
          "codeartifact:ListRepositoriesInDomain",
          "codeartifact:GetDomainPermissionsPolicy",
          "codeartifact:GetRepositoryPermissionsPolicy"
        ]
        Resource = [
          aws_codeartifact_domain.main.arn,
          "${aws_codeartifact_domain.main.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sts:GetServiceBearerToken"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "sts:AWSServiceName" = "codeartifact.amazonaws.com"
          }
        }
      }
    ]
  })
}



# IAM role for Lambda function
resource "aws_iam_role" "package_updater" {
  name = "${var.domain_name}-package-updater-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policies to Lambda role
resource "aws_iam_role_policy_attachment" "package_updater_basic" {
  role       = aws_iam_role.package_updater.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "package_updater_codeartifact" {
  role       = aws_iam_role.package_updater.name
  policy_arn = aws_iam_policy.codeartifact_access.arn
}

# CloudWatch Events rule to trigger package updates daily
resource "aws_cloudwatch_event_rule" "package_update_schedule" {
  name                = "${var.domain_name}-package-update-schedule"
  description         = "Trigger package updates daily"
  schedule_expression = "rate(1 day)"
}

# CloudWatch Events target
resource "aws_cloudwatch_event_target" "package_updater" {
  rule      = aws_cloudwatch_event_rule.package_update_schedule.name
  target_id = "PackageUpdater"
  arn       = aws_lambda_function.package_updater.arn
}

# Lambda permission for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.package_updater.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.package_update_schedule.arn
}

# Build Lambda deployment package with dependencies
resource "null_resource" "build_lambda_package" {
  triggers = {
    source_code_hash = filemd5("${path.module}/package_updater.py")
  }

  provisioner "local-exec" {
    command = "bash build_lambda.sh"
    working_dir = path.module
  }
}

# Lambda function to update package versions
resource "aws_lambda_function" "package_updater" {
  depends_on = [null_resource.build_lambda_package]
  filename         = "/tmp/package_updater.zip"
  function_name    = "${var.domain_name}-package-updater"
  role            = aws_iam_role.package_updater.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 300

  environment {
    variables = {
      DOMAIN_NAME = aws_codeartifact_domain.main.domain
      NPM_REPOSITORY = aws_codeartifact_repository.npm.repository
      PIP_REPOSITORY = aws_codeartifact_repository.pip.repository
      MAVEN_REPOSITORY = aws_codeartifact_repository.maven.repository
      GENERIC_REPOSITORY = aws_codeartifact_repository.generic.repository
    }
  }

  tags = var.tags
}
