# AWS CodeArtifact Setup for Security Tools

## Overview

This document describes the AWS CodeArtifact infrastructure setup for managing security tools and packages used in the CodeBuild Docker images. The setup includes automated package updates and centralized package management.

## Architecture

### CodeArtifact Domain and Repositories

The setup creates a CodeArtifact domain with the following repositories:

1. **generic-store**: For binary packages (trivy, grype, semgrep, tflint, terraform)
2. **pip-store**: For Python packages (checkov, bandit, npm-audit, pip-audit) - connected to PyPI
3. **npm-store**: For Node.js packages (npm, node) - connected to npmjs
4. **maven-store**: For Java-based tools - connected to Maven Central
5. **internal-store**: Aggregated repository with upstream connections to all other repositories

### Automated Package Updates

- **Lambda Function**: Daily package version checking and updates
- **CloudWatch Events**: Scheduled triggers for package updates
- **Package Sources**: GitHub releases, PyPI, HashiCorp checkpoint API

## Supported Packages

### Binary Tools
- **Trivy**: Container vulnerability scanner
- **Grype**: Vulnerability scanner for container images and filesystems
- **Semgrep**: Static analysis tool for security vulnerabilities
- **TFLint**: Terraform linter
- **Terraform**: Infrastructure as Code tool

### Python Packages
- **Checkov**: Infrastructure as Code security scanner
- **Bandit**: Security linter for Python code
- **npm-audit**: npm security audit tool
- **pip-audit**: pip security audit tool

### Node.js Packages
- **npm**: Node.js package manager
- **node**: Node.js runtime

## Deployment

### Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform installed
3. jq installed for JSON parsing

### Step 1: Deploy Infrastructure

```bash
cd terraform
terraform init
terraform apply -var="aws_region=us-east-1" \
                -var="codeartifact_domain_name=security-tools-domain"
```

### Step 2: Initialize Repositories

```bash
# Make script executable
chmod +x scripts/setup_codeartifact.sh

# Run setup script
./scripts/setup_codeartifact.sh
```

### Step 3: Verify Setup

```bash
# List repositories
aws codeartifact list-repositories-in-domain \
    --domain security-tools-domain \
    --region us-east-1

# List packages in generic repository
aws codeartifact list-packages \
    --domain security-tools-domain \
    --repository generic-store \
    --format generic \
    --region us-east-1
```

## Usage in Docker Images

### Base Image Configuration

The base Docker image is configured to use CodeArtifact for package installation:

```dockerfile
# Install security tools from CodeArtifact
RUN aws codeartifact get-authorization-token \
    --domain security-tools-domain \
    --region ${AWS_REGION:-us-east-1} \
    --query authorizationToken --output text > /tmp/codeartifact_token && \
    pip3.11 config set global.index-url \
    https://aws:$(cat /tmp/codeartifact_token)@security-tools-domain-${AWS_ACCOUNT_ID}.d.codeartifact.${AWS_REGION:-us-east-1}.amazonaws.com/pypi/pip-store/simple/ && \
    rm /tmp/codeartifact_token

# Install Python packages
RUN pip3.11 install checkov bandit
```

### Binary Tools Installation

Binary tools are installed using the `install_binary_tools.sh` script:

```bash
#!/bin/bash
# Script automatically downloads and installs latest versions
# from CodeArtifact generic repository
```

## Package Update Process

### Automated Updates

1. **Daily Trigger**: CloudWatch Events rule triggers Lambda function
2. **Version Check**: Lambda checks for new versions of all packages
3. **Download & Upload**: New versions are downloaded and uploaded to CodeArtifact
4. **Logging**: All activities are logged to CloudWatch

### Manual Updates

```bash
# Trigger Lambda function manually
aws lambda invoke \
    --function-name security-tools-domain-package-updater \
    --region us-east-1 \
    response.json
```

## Repository Endpoints

After deployment, the following endpoints are available:

- **Generic**: `https://security-tools-domain-{ACCOUNT_ID}.d.codeartifact.{REGION}.amazonaws.com/generic/generic-store/`
- **Pip**: `https://security-tools-domain-{ACCOUNT_ID}.d.codeartifact.{REGION}.amazonaws.com/pypi/pip-store/`
- **NPM**: `https://security-tools-domain-{ACCOUNT_ID}.d.codeartifact.{REGION}.amazonaws.com/npm/npm-store/`
- **Maven**: `https://security-tools-domain-{ACCOUNT_ID}.d.codeartifact.{REGION}.amazonaws.com/maven/maven-store/`

## Authentication

### Authorization Token

```bash
# Get authorization token
aws codeartifact get-authorization-token \
    --domain security-tools-domain \
    --region us-east-1 \
    --query authorizationToken --output text
```

### Repository Endpoint

```bash
# Get repository endpoint
aws codeartifact get-repository-endpoint \
    --domain security-tools-domain \
    --repository generic-store \
    --format generic \
    --region us-east-1
```

## Security

### IAM Permissions

The setup includes IAM policies for:
- CodeArtifact read/write access
- Lambda execution
- CloudWatch Events triggers

### Encryption

- Optional KMS encryption for CodeArtifact domain
- All data in transit is encrypted using TLS
- Repository permissions can be configured per repository

## Monitoring

### CloudWatch Logs

- Lambda function logs: `/aws/lambda/security-tools-domain-package-updater`
- CodeBuild logs: `/aws/codebuild/{project-name}`

### Metrics

- Package update success/failure rates
- Repository usage metrics
- Lambda function performance metrics

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   ```bash
   # Verify IAM permissions
   aws iam get-user
   aws sts get-caller-identity
   ```

2. **Package Upload Failures**
   ```bash
   # Check Lambda logs
   aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/security-tools-domain"
   ```

3. **Repository Access Issues**
   ```bash
   # Test repository access
   aws codeartifact describe-repository \
       --domain security-tools-domain \
       --repository generic-store \
       --region us-east-1
   ```

### Debugging

```bash
# Enable debug logging
export AWS_DEBUG=true

# Test package download
curl -H "Authorization: Bearer $(aws codeartifact get-authorization-token --domain security-tools-domain --region us-east-1 --query authorizationToken --output text)" \
     "https://security-tools-domain-{ACCOUNT_ID}.d.codeartifact.{REGION}.amazonaws.com/generic/generic-store/security-tools/trivy/latest/trivy-latest.tar.gz"
```

## Cost Optimization

### Storage Costs

- CodeArtifact charges for storage and data transfer
- Consider lifecycle policies for old package versions
- Monitor repository usage and clean up unused packages

### Lambda Costs

- Function runs daily (minimal cost)
- Consider adjusting schedule based on update frequency needs
- Monitor function duration and memory usage

## Best Practices

1. **Version Management**: Keep multiple versions for rollback capability
2. **Security Scanning**: Regularly scan packages for vulnerabilities
3. **Access Control**: Use least-privilege IAM policies
4. **Monitoring**: Set up alerts for package update failures
5. **Backup**: Consider cross-region replication for critical packages

## Future Enhancements

1. **Additional Package Types**: Support for Go modules, Ruby gems
2. **Vulnerability Scanning**: Integrate with AWS Security Hub
3. **Package Signing**: Implement package signature verification
4. **Multi-Region**: Deploy across multiple AWS regions
5. **Custom Packages**: Support for internal/custom packages
