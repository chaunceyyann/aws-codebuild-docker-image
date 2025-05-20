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
RUN wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip && \
    unzip terraform_1.6.6_linux_amd64.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform_1.6.6_linux_amd64.zip

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