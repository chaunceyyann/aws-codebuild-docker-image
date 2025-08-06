#!/bin/bash

# Script to setup CodeArtifact repositories with latest security tools
set -e

# Configuration
DOMAIN_NAME=${DOMAIN_NAME:-security-tools-domain}
AWS_REGION=${AWS_REGION:-us-east-1}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}

echo "Setting up CodeArtifact repositories..."
echo "Domain: $DOMAIN_NAME"
echo "Region: $AWS_REGION"
echo "Account: $AWS_ACCOUNT_ID"

# Function to get latest version from GitHub releases
get_github_latest_version() {
    local repo=$1
    curl -s "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name' | sed 's/v//'
}

# Function to get latest version from HashiCorp checkpoint
get_terraform_version() {
    curl -s "https://checkpoint-api.hashicorp.com/v1/check/terraform" | jq -r '.current_version'
}

# Function to get latest version from PyPI
get_pypi_latest_version() {
    local package=$1
    curl -s "https://pypi.org/pypi/$package/json" | jq -r '.info.version'
}

# Function to upload binary package to CodeArtifact
upload_binary_package() {
    local tool_name=$1
    local version=$2
    local download_url=$3
    local asset_name=$4

    echo "Uploading $tool_name version $version..."

    # Download the binary
    curl -L -o "/tmp/${tool_name}-${version}.tar.gz" "$download_url"

    # Upload to CodeArtifact
    aws codeartifact upload-package-version-asset \
        --domain $DOMAIN_NAME \
        --repository generic-store \
        --format generic \
        --namespace security-tools \
        --package $tool_name \
        --package-version $version \
        --asset-name "${asset_name}-${version}.tar.gz" \
        --asset file:///tmp/${tool_name}-${version}.tar.gz \
        --region $AWS_REGION

    # Clean up
    rm "/tmp/${tool_name}-${version}.tar.gz"
    echo "$tool_name $version uploaded successfully"
}

# Function to upload pip package to CodeArtifact
upload_pip_package() {
    local package_name=$1
    local version=$2

    echo "Uploading pip package $package_name version $version..."

    # Create temporary directory
    TEMP_DIR=$(mktemp -d)

    # Download package
    pip download --index-url https://pypi.org/simple/ --dest $TEMP_DIR "${package_name}==${version}"

    # Find the downloaded file
    for file in $TEMP_DIR/*; do
        if [[ $file == *.whl || $file == *.tar.gz ]]; then
            aws codeartifact upload-package-version-asset \
                --domain $DOMAIN_NAME \
                --repository pip-store \
                --format pypi \
                --namespace security-tools \
                --package $package_name \
                --package-version $version \
                --asset-name $(basename $file) \
                --asset file://$file \
                --region $AWS_REGION
            break
        fi
    done

    # Clean up
    rm -rf $TEMP_DIR
    echo "$package_name $version uploaded successfully"
}

# Get latest versions
echo "Getting latest package versions..."

TRIVY_VERSION=$(get_github_latest_version "aquasecurity/trivy")
GRYPE_VERSION=$(get_github_latest_version "anchore/grype")
SEMGREP_VERSION=$(get_github_latest_version "returntocorp/semgrep")
TFLINT_VERSION=$(get_github_latest_version "terraform-linters/tflint")
TERRAFORM_VERSION=$(get_terraform_version)
CHECKOV_VERSION=$(get_pypi_latest_version "checkov")
BANDIT_VERSION=$(get_pypi_latest_version "bandit")

echo "Latest versions:"
echo "  Trivy: $TRIVY_VERSION"
echo "  Grype: $GRYPE_VERSION"
echo "  Semgrep: $SEMGREP_VERSION"
echo "  TFLint: $TFLINT_VERSION"
echo "  Terraform: $TERRAFORM_VERSION"
echo "  Checkov: $CHECKOV_VERSION"
echo "  Bandit: $BANDIT_VERSION"

# Upload binary packages
echo "Uploading binary packages to generic repository..."

upload_binary_package "trivy" "$TRIVY_VERSION" \
    "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" \
    "trivy"

upload_binary_package "grype" "$GRYPE_VERSION" \
    "https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/grype_${GRYPE_VERSION}_linux_amd64.tar.gz" \
    "grype"

upload_binary_package "semgrep" "$SEMGREP_VERSION" \
    "https://github.com/returntocorp/semgrep/releases/download/v${SEMGREP_VERSION}/semgrep-v${SEMGREP_VERSION}-ubuntu-16.04.tgz" \
    "semgrep"

upload_binary_package "tflint" "$TFLINT_VERSION" \
    "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip" \
    "tflint"

upload_binary_package "terraform" "$TERRAFORM_VERSION" \
    "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    "terraform"

# Upload pip packages
echo "Uploading pip packages to pip repository..."

upload_pip_package "checkov" "$CHECKOV_VERSION"
upload_pip_package "bandit" "$BANDIT_VERSION"

echo "CodeArtifact setup completed successfully!"
echo ""
echo "Repository endpoints:"
echo "  Generic: https://${DOMAIN_NAME}-${AWS_ACCOUNT_ID}.d.codeartifact.${AWS_REGION}.amazonaws.com/generic/generic-store/"
echo "  Pip: https://${DOMAIN_NAME}-${AWS_ACCOUNT_ID}.d.codeartifact.${AWS_REGION}.amazonaws.com/pypi/pip-store/"
echo "  NPM: https://${DOMAIN_NAME}-${AWS_ACCOUNT_ID}.d.codeartifact.${AWS_REGION}.amazonaws.com/npm/npm-store/"
echo "  Maven: https://${DOMAIN_NAME}-${AWS_ACCOUNT_ID}.d.codeartifact.${AWS_REGION}.amazonaws.com/maven/maven-store/"
