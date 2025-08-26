# aws-global-infra/Dockerfile

# Use our base image from ECR
ARG ECR_REPO_URL
FROM ${ECR_REPO_URL}:latest

# Display OS release information
RUN cat /etc/os-release

# Install latest Grype (vulnerability scanner)
RUN curl -fsSL https://github.com/anchore/grype/releases/latest/download/grype_$(curl -s https://api.github.com/repos/anchore/grype/releases/latest | jq -r '.tag_name' | sed 's/v//')_linux_amd64.tar.gz | \
    tar -xzC /usr/local/bin grype && \
    chmod +x /usr/local/bin/grype

# Install latest Trivy (vulnerability scanner)
RUN curl -fsSL https://github.com/aquasecurity/trivy/releases/latest/download/trivy_$(curl -s https://api.github.com/repos/aquasecurity/trivy/releases/latest | jq -r '.tag_name' | sed 's/v//')_Linux-64bit.tar.gz | \
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
    echo "GitHub CLI version: $(gh --version)" && \
    echo "Node.js version: $(node --version)" && \
    echo "npm version: $(npm --version)" && \
    echo "\nScanner image tools:" && \
    echo "Grype version: $(grype --version)" && \
    echo "Trivy version: $(trivy --version)"

# Set entrypoint for CodeBuild compatibility
ENTRYPOINT ["/bin/bash"]
