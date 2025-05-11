# aws-codebuild-docker-image/Dockerfile

# Use Amazon Linux 2 as the base image (aligned with CodeBuild standard:5.0)
FROM public.ecr.aws/codebuild/amazonlinux2-x86_64-standard:5.0

# Set working directory
WORKDIR /app

# Install base dependencies and OpenSSL (for secure Git operations)
RUN yum update -y && \
    yum install -y \
    python3.10 \
    python3-pip \
    git \
    openssl \
    unzip \
    curl \
    jq \
    tar \
    gzip && \
    yum clean all

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Install Docker
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-20.10.9.tgz | \
    tar -xzC /usr/local/bin --strip-components=1 docker/docker && \
    chmod +x /usr/local/bin/docker

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

# Install Node.js 18
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
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

# Install pip packages
RUN pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir awscli

# Set non-root user for security
RUN useradd -m codebuild-user
USER codebuild-user

# Verify installations
RUN python3 --version && \
    pip3 --version && \
    aws --version && \
    docker --version && \
    terraform version && \
    tflint --version && \
    node --version && \
    npm --version && \
    grype --version && \
    trivy --version

# Set entrypoint for CodeBuild compatibility
ENTRYPOINT ["/bin/bash"]