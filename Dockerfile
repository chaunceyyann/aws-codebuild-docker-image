FROM amazonlinux:2

# Install basic utilities
RUN yum update -y && \
    yum install -y \
    tar \
    gzip \
    unzip \
    git \
    wget \
    curl \
    jq \
    python3 \
    python3-pip \
    && yum clean all

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Install Terraform 1.6.6
RUN curl -fsSL https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip -o terraform.zip && \
    unzip terraform.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/terraform && \
    rm terraform.zip

# Install tflint
RUN curl -fsSL https://github.com/terraform-linters/tflint/releases/download/v0.50.0/tflint_linux_amd64.zip -o tflint.zip && \
    unzip tflint.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/tflint && \
    rm tflint.zip

# Install Docker
RUN amazon-linux-extras install docker -y && \
    yum install -y docker && \
    systemctl enable docker

# Install Docker Compose
RUN curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
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