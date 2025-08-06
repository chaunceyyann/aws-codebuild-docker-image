#!/bin/bash

# Script to install binary security tools from CodeArtifact
set -e

# Get AWS account ID and region
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}
AWS_REGION=${AWS_REGION:-us-east-1}
DOMAIN_NAME=${DOMAIN_NAME:-security-tools-domain}
REPOSITORY_NAME=${REPOSITORY_NAME:-generic-store}

# Get CodeArtifact auth token
echo "Getting CodeArtifact authorization token..."
TOKEN=$(aws codeartifact get-authorization-token \
    --domain $DOMAIN_NAME \
    --region $AWS_REGION \
    --query authorizationToken \
    --output text)

# Get repository endpoint
echo "Getting repository endpoint..."
ENDPOINT=$(aws codeartifact get-repository-endpoint \
    --domain $DOMAIN_NAME \
    --repository $REPOSITORY_NAME \
    --format generic \
    --region $AWS_REGION \
    --query repositoryEndpoint \
    --output text)

# Function to download and install binary tool
install_binary_tool() {
    local tool_name=$1
    local version=$2

    echo "Installing $tool_name version $version..."

    # Download from CodeArtifact
    curl -H "Authorization: Bearer $TOKEN" \
         -o "/tmp/${tool_name}-${version}.tar.gz" \
         "${ENDPOINT}/security-tools/${tool_name}/${version}/${tool_name}-${version}.tar.gz"

    # Extract and install
    case $tool_name in
        "trivy")
            tar -xzf "/tmp/${tool_name}-${version}.tar.gz" -C /tmp
            mv /tmp/trivy /usr/local/bin/
            chmod +x /usr/local/bin/trivy
            ;;
        "grype")
            tar -xzf "/tmp/${tool_name}-${version}.tar.gz" -C /tmp
            mv /tmp/grype /usr/local/bin/
            chmod +x /usr/local/bin/grype
            ;;
        "semgrep")
            tar -xzf "/tmp/${tool_name}-${version}.tar.gz" -C /tmp
            mv /tmp/semgrep /usr/local/bin/
            chmod +x /usr/local/bin/semgrep
            ;;
        "tflint")
            unzip "/tmp/${tool_name}-${version}.tar.gz" -d /tmp
            mv /tmp/tflint /usr/local/bin/
            chmod +x /usr/local/bin/tflint
            ;;
        "terraform")
            unzip "/tmp/${tool_name}-${version}.tar.gz" -d /tmp
            mv /tmp/terraform /usr/local/bin/
            chmod +x /usr/local/bin/terraform
            ;;
        *)
            echo "Unknown tool: $tool_name"
            return 1
            ;;
    esac

    # Clean up
    rm "/tmp/${tool_name}-${version}.tar.gz"
    echo "$tool_name $version installed successfully"
}

# Get latest versions from CodeArtifact
echo "Getting latest package versions..."

# List available packages and get latest versions
PACKAGES=$(aws codeartifact list-packages \
    --domain $DOMAIN_NAME \
    --repository $REPOSITORY_NAME \
    --format generic \
    --region $AWS_REGION \
    --query 'packages[].package' \
    --output text)

for package in $PACKAGES; do
    if [[ "$package" =~ ^(trivy|grype|semgrep|tflint|terraform)$ ]]; then
        # Get latest version
        LATEST_VERSION=$(aws codeartifact list-package-versions \
            --domain $DOMAIN_NAME \
            --repository $REPOSITORY_NAME \
            --format generic \
            --namespace security-tools \
            --package $package \
            --region $AWS_REGION \
            --query 'sort_by(versions[].version, &version)[-1].version' \
            --output text)

        if [ "$LATEST_VERSION" != "None" ]; then
            install_binary_tool $package $LATEST_VERSION
        fi
    fi
done

echo "Binary tools installation completed!"
