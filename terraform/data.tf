# aws-global-infra/terraform/data.tf

# GitHub OAuth token from Secrets Manager
data "aws_secretsmanager_secret" "github_token" {
  name = "codebuild/github-oauth-token"
}

# Current AWS account identity
data "aws_caller_identity" "current" {}
