FROM amazonlinux:2023

# Install basic utilities and Python 3.11
RUN dnf update -y && \
    dnf install -y \
    tar \
    gzip \
    unzip \
    git \
    jq \
    python3.11 \
    python3.11-pip \
    wget \
    && dnf clean all

# Display OS release iformation
RUN cat /etc/os-release

# Install latest YQ dynamically
RUN curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

# Install AWS CLI v2 (latest)
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

RUN curl -fsSL https://releases.hashicorp.com/terraform/$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r '.current_version')/terraform_$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r '.current_version')_linux_amd64.zip -o terraform.zip && \
    unzip terraform.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/terraform && \
    rm terraform.zip

RUN curl -fsSL https://github.com/terraform-linters/tflint/releases/latest/download/tflint_linux_amd64.zip -o tflint.zip && \
    unzip tflint.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/tflint && \
    rm tflint.zip

# Install GitHub CLI (latest)
RUN curl -fsSL https://github.com/cli/cli/releases/latest/download/gh_$(curl -s https://api.github.com/repos/cli/cli/releases/latest | jq -r '.tag_name' | sed 's/v//')_linux_amd64.tar.gz | tar -xz && \
    mv gh_*_linux_amd64/bin/gh /usr/local/bin/ && \
    rm -rf gh_*_linux_amd64

# Install Node.js (latest LTS)
RUN curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash - && \
    dnf install -y nodejs && \
    dnf clean all

# Install Python packages
RUN pip3.11 install boto3 requests

# Install Go (latest)
RUN curl -fsSL https://go.dev/dl/$(curl -s https://go.dev/dl/ | grep -o 'go[0-9]\+\.[0-9]\+\.[0-9]\+\.linux-amd64\.tar\.gz' | head -1) -o go.tar.gz && \
    tar -C /usr/local -xzf go.tar.gz && \
    rm go.tar.gz && \
    ln -s /usr/local/go/bin/go /usr/local/bin/go && \
    ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt

# Set working directory
WORKDIR /workspace

# Verify all installations
RUN echo "=== VERIFYING ALL TOOLS ===" && \
    echo "Python 3.11: $(python3.11 --version)" && \
    echo "pip 3.11: $(pip3.11 --version)" && \
    echo "AWS CLI: $(aws --version)" && \
    echo "Terraform: $(terraform version)" && \
    echo "TFLint: $(tflint --version)" && \
    echo "GitHub CLI: $(gh --version)" && \
    echo "Node.js: $(node --version)" && \
    echo "npm: $(npm --version)" && \
    echo "Go: $(go version)" && \
    echo "Git: $(git --version)" && \
    echo "Curl: $(curl --version)" && \
    echo "JQ: $(jq --version)" && \
    echo "YQ: $(yq --version)" && \
    echo "=== ALL TOOLS VERIFIED ==="

# Default command
CMD ["/bin/bash"]
