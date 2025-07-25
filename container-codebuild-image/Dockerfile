FROM amazonlinux:2023

# Install basic utilities
RUN dnf update -y && \
    dnf install -y \
    tar \
    gzip \
    unzip \
    git \
    jq \
    python3 \
    python3-pip \
    && yum clean all

# Display OS release information
RUN cat /etc/os-release

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Install latest Terraform
RUN curl -fsSL https://releases.hashicorp.com/terraform/$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r '.current_version')/terraform_$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r '.current_version')_linux_amd64.zip -o terraform.zip && \
    unzip terraform.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/terraform && \
    rm terraform.zip

# Install latest TFLint
RUN curl -fsSL https://github.com/terraform-linters/tflint/releases/latest/download/tflint_linux_amd64.zip -o tflint.zip && \
    unzip tflint.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/tflint && \
    rm tflint.zip

# Install Docker
RUN dnf install -y docker && \
    systemctl enable docker

# Install latest Docker Compose
RUN curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose

# Add any other tools or configurations needed for your builds
RUN pip3 install --upgrade pip && \
    pip3 install boto3

# Set working directory
WORKDIR /workspace

# Add a healthcheck
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Default command
CMD ["/bin/bash"]
