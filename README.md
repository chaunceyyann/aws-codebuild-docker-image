# AWS CodeBuild Secure Docker Image Pipeline

## Overview
This project automates the daily creation of a customized, secure Docker image for AWS CodeBuild using AWS CodePipeline and CodeBuild. Built from a default Amazon Linux 2 AMI, the image includes Python 3.10, pip, Docker, Terraform 1.6.6, tflint, AWS CLI, Node.js, and security tools Grype and Trivy for vulnerability scanning. The Terraform-defined pipeline builds, tests, and pushes the image to Amazon ECR, ensuring compliance and security for consistent CI/CD workflows across CodeBuild projects.

## Features
- **Custom Docker Image**: Includes Python 3.10, pip, Docker, Terraform 1.6.6, tflint, AWS CLI, Node.js, Grype, and Trivy.
- **Automated Pipeline**: Daily builds via AWS CodePipeline/CodeBuild, with compliance and vulnerability tests.
- **Security**: Grype and Trivy scan for vulnerabilities, ensuring a secure baseline image.
- **ECR Integration**: Pushes images to Amazon ECR for use in CodeBuild environments.
- **Terraform-Driven**: Infrastructure and pipeline defined as code for reproducibility.

## Prerequisites
- **AWS Account**: Permissions for CodePipeline, CodeBuild, ECR, IAM, and S3.
- **Terraform**: Version 1.6.6 installed locally for pipeline deployment.
- **AWS CLI**: Configured with credentials (`aws configure`).
- **Docker**: Installed locally for testing (e.g., Docker Desktop).
- **Git**: For cloning the repository.
- **OpenSSL**: Required for secure Git operations (e.g., HTTPS cloning).

## Installation
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/<your-repo>/secure-codebuild-image.git
   cd secure-codebuild-image
   ```
   Ensure OpenSSL is installed to avoid `SSL_ERROR_SYSCALL` (e.g., `sudo apt install openssl` on Ubuntu).

2. **Configure AWS CLI**:
   ```bash
   aws configure
   ```
   Set Access Key, Secret Key, region (e.g., `us-east-1`), and output format.

3. **Deploy Terraform Infrastructure**:
   ```bash
   terraform init
   terraform apply -var="aws_region=us-east-1" -var="ecr_repo_name=secure-codebuild-image"
   ```

4. **Build the Docker Image Locally** (optional):
   ```bash
   docker build -t secure-codebuild-image:latest .
   ```

## Usage
1. **Customize the Dockerfile**:
   - Edit `Dockerfile` to adjust tools or versions.
   - Example:
     ```dockerfile
     FROM public.ecr.aws/codebuild/amazonlinux2-x86_64-standard:5.0
     RUN yum install -y python3.10 python3-pip git openssl
     RUN pip3 install awscli
     RUN curl -Lo /tmp/terraform.zip https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip \
         && unzip /tmp/terraform.zip -d /usr/local/bin
     RUN curl -Lo /usr/local/bin/tflint https://github.com/terraform-linters/tflint/releases/download/v0.50.0/tflint_linux_amd64 \
         && chmod +x /usr/local/bin/tflint
     RUN curl -sL https://deb.nodesource.com/setup_18.x | bash - && yum install -y nodejs
     RUN curl -Lo /usr/local/bin/grype https://github.com/anchore/grype/releases/download/v0.73.0/grype_0.73.0_linux_amd64 \
         && chmod +x /usr/local/bin/grype
     RUN curl -Lo /usr/local/bin/trivy https://github.com/aquasecurity/trivy/releases/download/v0.50.0/trivy_0.50.0_Linux-64bit \
         && chmod +x /usr/local/bin/trivy
     RUN curl -Lo /usr/local/bin/docker https://download.docker.com/linux/static/stable/x86_64/docker-20.10.9.tgz \
         && chmod +x /usr/local/bin/docker
     ```

2. **Run the Pipeline**:
   - The pipeline (defined in `pipeline.tf`) triggers daily via a CloudWatch Events rule.
   - `buildspec.yml` orchestrates build, test, and push:
     ```yaml
     version: 0.2
     phases:
       pre_build:
         commands:
           - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
       build:
         commands:
           - docker build -t $ECR_REGISTRY/$REPO_NAME:latest .
           - grype $ECR_REGISTRY/$REPO_NAME:latest
           - trivy image $ECR_REGISTRY/$REPO_NAME:latest
       post_build:
         commands:
           - docker push $ECR_REGISTRY/$REPO_NAME:latest
     ```
   - Deploy via Terraform or manually start the CodeBuild project.

3. **Use in CodeBuild**:
   - Configure CodeBuild projects to use the ECR image (e.g., `<account-id>.dkr.ecr.<region>.amazonaws.com/secure-codebuild-image:latest`).

## Directory Structure
```
├── Dockerfile         # Custom Docker image definition
├── buildspec.yml      # CodeBuild pipeline configuration
├── terraform/         # Terraform files for pipeline and infrastructure
│   ├── main.tf       # Pipeline, CodeBuild, ECR, IAM setup
│   ├── variables.tf  # Configuration variables
│   └── outputs.tf    # Output ECR repository URL
├── scripts/           # Utility scripts (e.g., test.sh)
└── README.md          # Project documentation
```

## Configuration
- **Environment Variables**:
  - `AWS_REGION`: AWS region (e.g., `us-east-1`).
  - `ECR_REGISTRY`: ECR registry URL (e.g., `<account-id>.dkr.ecr.<region>.amazonaws.com`).
  - `REPO_NAME`: ECR repository name (e.g., `secure-codebuild-image`).
- **Terraform Variables**:
  - Edit `terraform/variables.tf` for region, repo name, and schedule (default: daily).
- **Proxy Setup** (if applicable):
  ```bash
  export http_proxy=http://proxy.example.com:8080
  export https_proxy=http://proxy.example.com:8080
  ```

## Testing
- **Local Testing**:
  ```bash
  docker run -it secure-codebuild-image:latest bash
  python3 --version  # 3.10
  terraform version  # 1.6.6
  grype --version
  trivy --version
  ```
- **Pipeline Testing**:
  - Trigger CodeBuild manually to verify build, vulnerability scans, and ECR push.
  - Check CloudWatch logs for Grype/Trivy scan results.

## Security
- **Vulnerability Scanning**: Grype and Trivy ensure the image is free of critical vulnerabilities.
- **Compliance**: Non-root user, minimal base image, and daily updates reduce attack surface.
- **IAM Roles**: Use least-privilege roles for CodeBuild and CodePipeline (defined in `main.tf`).

## Contributing
- Submit issues or pull requests to `<repository-url>`.
- Include tests for new features and update `buildspec.yml` as needed.

## License
MIT License. See `LICENSE` for details.

## Contact
For support, contact `<your-email>` or open an issue on GitHub.