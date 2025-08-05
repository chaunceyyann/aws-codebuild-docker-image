# GitHub Actions Runners with AWS CodeBuild

This project provides a scalable solution for creating GitHub Actions runners using AWS CodeBuild projects. Each CodeBuild project acts as a self-hosted runner for a specific GitHub repository.

## Overview

The setup allows you to:
- Create multiple CodeBuild projects, each acting as a GitHub Actions runner
- Name each runner after its corresponding GitHub repository
- Enable webhooks for automatic builds on code changes
- Use custom Docker images with pre-installed tools
- Configure different runner types for different use cases

## Architecture

```
GitHub Repository A → CodeBuild Project A (Runner A)
GitHub Repository B → CodeBuild Project B (Runner B)
GitHub Repository C → CodeBuild Project C (Runner C)
```

Each CodeBuild project:
- Connects to a specific GitHub repository
- Uses a custom Docker image with development tools
- Has webhook enabled for automatic builds
- Acts as a GitHub Actions self-hosted runner

## Configuration

### 1. Module Variables

The CodeBuild module supports these new variables for GitHub Actions runners:

```hcl
variable "enable_github_actions_runner" {
  description = "Enable this CodeBuild project as a GitHub Actions runner"
  type        = bool
  default     = false
}

variable "github_owner" {
  description = "GitHub repository owner (user or organization)"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = ""
}

variable "github_branch" {
  description = "GitHub branch to monitor for webhooks"
  type        = string
  default     = "main"
}

variable "webhook_enabled" {
  description = "Enable webhook for automatic builds on code changes"
  type        = bool
  default     = false
}
```

### 2. Example Usage

```hcl
# Runner for repository "my-python-app"
module "codebuild_runner_python_app" {
  source                = "./modules/codebuild"
  project_name          = "runner-my-python-app"
  aws_region            = var.aws_region
  ecr_repository_arn    = module.ecr.repository_arn
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecr_repo_url          = module.ecr.repository_url
  image_version         = "1.0.0"
  image                 = "${module.ecr.repository_url}:latest"
  source_repository_url = "https://github.com/chaunceyyann/my-python-app"
  description           = "GitHub Actions runner for my-python-app repository"
  buildspec_path        = ".github/buildspecs/runner.yml"

  # GitHub Actions runner configuration
  enable_github_actions_runner = true
  github_owner                 = "chaunceyyann"
  github_repo                  = "my-python-app"
  github_branch                = "main"

  # Enable webhook for automatic builds
  webhook_enabled = true

  environment_type = "LINUX_CONTAINER"
  compute_type     = "BUILD_GENERAL1_MEDIUM"
  privileged_mode  = false

  environment_variables = [
    {
      name  = "RUNNER_TYPE"
      value = "python-app"
      type  = "PLAINTEXT"
    }
  ]
}
```

### 3. Buildspec Configuration

Each runner uses a common buildspec file (`.github/buildspecs/runner.yml`) that:

- Detects the runner type from environment variables
- Sets up the appropriate environment based on the runner type
- Executes runner-specific tasks
- Provides build artifacts

## Runner Types

### Python App Runner
- **Use Case**: Python applications, data science projects
- **Tools**: Python, pip, virtual environments
- **Environment Variables**: `RUNNER_TYPE=python-app`

### Node.js API Runner
- **Use Case**: Node.js applications, APIs, frontend projects
- **Tools**: Node.js, npm, yarn
- **Environment Variables**: `RUNNER_TYPE=nodejs-api`

### Terraform Infrastructure Runner
- **Use Case**: Infrastructure as Code, Terraform deployments
- **Tools**: Terraform, TFLint, AWS CLI
- **Environment Variables**: `RUNNER_TYPE=terraform-infra`

## Webhook Configuration

Each runner can be configured with webhooks to trigger builds automatically:

```hcl
webhook_filter_groups = [
  [
    {
      type                 = "EVENT"
      pattern              = "PUSH"
      exclude_matched_pattern = false
    },
    {
      type                 = "HEAD_REF"
      pattern              = "refs/heads/main"
      exclude_matched_pattern = false
    },
    {
      type                 = "HEAD_REF"
      pattern              = "refs/heads/develop"
      exclude_matched_pattern = false
    }
  ]
]
```

## GitHub Actions Integration

To use these runners in your GitHub Actions workflows:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: codebuild-runner-my-python-app
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: |
          python -m pytest
```

## Security Considerations

1. **IAM Permissions**: Each runner has minimal required permissions
2. **VPC Isolation**: Runners run in private subnets with NAT Gateway
3. **Secrets Management**: GitHub tokens stored in AWS Secrets Manager
4. **Network Security**: Security groups restrict network access

## Monitoring and Logging

- CloudWatch Logs: `/aws/codebuild/{project-name}`
- Build artifacts stored in S3
- Build status reported back to GitHub

## Scaling

To add more runners:

1. Create a new module instance in `main.tf`
2. Configure the GitHub repository details
3. Set appropriate environment variables
4. Deploy with Terraform

## Troubleshooting

### Common Issues

1. **Webhook not triggering**: Check GitHub repository permissions
2. **Build failures**: Verify buildspec file path and syntax
3. **Authentication errors**: Ensure GitHub token is valid in Secrets Manager
4. **Network issues**: Check VPC and security group configuration

### Debugging

- Check CloudWatch logs for detailed error messages
- Verify environment variables are set correctly
- Ensure the custom Docker image is accessible
- Confirm GitHub repository access permissions
