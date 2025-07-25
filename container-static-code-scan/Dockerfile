# aws-codebuild-docker-image/Dockerfile

# Use our base image from ECR
ARG ECR_REPO_URL
FROM ${ECR_REPO_URL}:latest

# Display OS release information
RUN cat /etc/os-release

# Install Node.js 18.x
RUN curl -sL https://rpm.nodesource.com/setup_18.x | bash - && \
    yum install -y nodejs && \
    yum clean all

# Install Grype (vulnerability scanner)
RUN curl -fsSL https://github.com/anchore/grype/releases/download/v0.73.0/grype_0.73.0_linux_amd64.tar.gz | \
    tar -xzC /usr/local/bin grype && \
    chmod +x /usr/local/bin/grype

# Install Trivy (vulnerability scanner)
RUN curl -fsSL https://github.com/aquasecurity/trivy/releases/download/v0.50.0/trivy_0.50.0_Linux-64bit.tar.gz | \
    tar -xzC /usr/local/bin trivy && \
    chmod +x /usr/local/bin/trivy

# Verify all installations (base image + new tools)
RUN echo "Verifying installations..." && \
    echo "Base image tools:" && \
    echo "Python version: $(python3 --version)" && \
    echo "pip version: $(pip3 --version)" && \
    echo "AWS CLI version: $(aws --version)" && \
    echo "Terraform version: $(terraform version)" && \
    echo "tflint version: $(tflint --version)" && \
    echo "Docker version: $(docker --version)" && \
    echo "Docker Compose version: $(docker-compose --version)" && \
    echo "\nScanner image tools:" && \
    echo "Node.js version: $(node --version)" && \
    echo "npm version: $(npm --version)" && \
    echo "Grype version: $(grype --version)" && \
    echo "Trivy version: $(trivy --version)"

# Set entrypoint for CodeBuild compatibility
ENTRYPOINT ["/bin/bash"]
