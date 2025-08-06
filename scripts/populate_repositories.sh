#!/bin/bash

# Script to populate CodeArtifact repositories with packages from public sources
set -e

# Configuration
DOMAIN_NAME=${DOMAIN_NAME:-security-tools-domain}
AWS_REGION=${AWS_REGION:-us-east-1}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}

echo "🚀 Populating CodeArtifact repositories..."
echo "Domain: $DOMAIN_NAME"
echo "Region: $AWS_REGION"
echo "Account: $AWS_ACCOUNT_ID"
echo ""

# Function to get authorization token
get_auth_token() {
    aws codeartifact get-authorization-token \
        --domain $DOMAIN_NAME \
        --region $AWS_REGION \
        --query authorizationToken \
        --output text
}

# Function to refresh authentication tokens
refresh_tokens() {
    echo "🔄 Refreshing authentication tokens..."

    # Get fresh token for pip
    export PIP_TOKEN=$(get_auth_token)

    # Refresh npm authentication
    configure_npm

    echo "✅ Authentication tokens refreshed"
}

# Function to get repository endpoint
get_repository_endpoint() {
    local repository=$1
    local format_type=$2

    aws codeartifact get-repository-endpoint \
        --domain $DOMAIN_NAME \
        --repository $repository \
        --format $format_type \
        --region $AWS_REGION \
        --query repositoryEndpoint \
        --output text
}

# Function to configure npm for CodeArtifact
configure_npm() {
    echo "📦 Configuring npm for CodeArtifact..."

    # Clear any existing npm configuration
    npm config delete registry 2>/dev/null || true
    npm config delete //security-tools-domain-643843550246.d.codeartifact.us-east-1.amazonaws.com:_authToken 2>/dev/null || true

    # Use AWS CLI to configure npm for CodeArtifact (this gets a fresh token)
    aws codeartifact login --tool npm --repository npm-store --domain $DOMAIN_NAME --region $AWS_REGION

    if [ $? -eq 0 ]; then
        echo "✅ npm configured for CodeArtifact using AWS CLI"
    else
        echo "⚠️  AWS CLI login failed, trying manual configuration..."

        local token=$(get_auth_token)
        local endpoint=$(get_repository_endpoint "npm-store" "npm")

        # Extract domain from endpoint for proper npm configuration
        local domain=$(echo $endpoint | sed 's|https://\([^/]*\).*|\1|')

        # Configure npm to use CodeArtifact with proper authentication
        npm config set registry $endpoint
        npm config set //$domain:_authToken $token

        echo "✅ npm configured for CodeArtifact manually"
    fi
}

# Function to configure pip for CodeArtifact
configure_pip() {
    echo "🐍 Configuring pip for CodeArtifact..."

    local token=$(get_auth_token)
    local endpoint=$(get_repository_endpoint "pip-store" "pypi")

    # Configure pip to use CodeArtifact
    pip config set global.index-url https://aws:$token@$endpoint/simple/
    pip config set global.extra-index-url https://pypi.org/simple/

    echo "✅ pip configured for CodeArtifact"
}

# Function to populate npm repository
populate_npm() {
    echo "📦 Populating npm repository..."

    # List of npm packages to install
    local packages=(
        "npm@latest"
        "yarn@latest"
        "typescript@latest"
        "eslint@latest"
        "prettier@latest"
        "jest@latest"
        "webpack@latest"
        "babel-core@latest"
        "react@latest"
        "vue@latest"
        "angular@latest"
        "lodash@latest"
        "express@latest"
        "axios@latest"
    )

    for package in "${packages[@]}"; do
        echo "Installing $package..."
        npm install $package
    done

    echo "✅ npm repository populated"
}

# Function to populate pip repository
populate_pip() {
    echo "🐍 Populating pip repository..."

    # List of Python packages to install
    local packages=(
        "checkov"
        "bandit"
        "safety"
        "pip-audit"
        "semgrep"
        "black"
        "flake8"
        "mypy"
        "pytest"
        "requests"
        "boto3"
        "pandas"
        "numpy"
        "matplotlib"
        "scikit-learn"
        "fastapi"
        "django"
        "flask"
    )

    for package in "${packages[@]}"; do
        echo "Installing $package..."
        pip install $package --index-url $(get_repository_endpoint "pip-store" "pypi")/simple/
    done

    echo "✅ pip repository populated"
}

# Function to populate maven repository
populate_maven() {
    echo "☕ Populating Maven repository..."

    # This would require Maven to be configured with CodeArtifact
    # For now, we'll show the configuration steps
    echo "To populate Maven repository, configure Maven settings.xml:"
    echo "1. Get the Maven endpoint: $(get_repository_endpoint "maven-store" "maven")"
    echo "2. Add repository configuration to ~/.m2/settings.xml"
    echo "3. Run: mvn dependency:resolve"

    echo "✅ Maven repository configuration provided"
}

# Function to populate generic repository with binary tools
populate_generic() {
    echo "🔧 Populating generic repository with binary tools..."

    # Get latest versions
    local trivy_version=$(curl -s "https://api.github.com/repos/aquasecurity/trivy/releases/latest" | jq -r '.tag_name' | sed 's/v//')
    local grype_version=$(curl -s "https://api.github.com/repos/anchore/grype/releases/latest" | jq -r '.tag_name' | sed 's/v//')
    local terraform_version=$(curl -s "https://checkpoint-api.hashicorp.com/v1/check/terraform" | jq -r '.current_version')

    echo "Latest versions:"
    echo "  Trivy: $trivy_version"
    echo "  Grype: $grype_version"
    echo "  Terraform: $terraform_version"

    # Download and upload binary tools
    local tools=(
        "trivy:https://github.com/aquasecurity/trivy/releases/download/v${trivy_version}/trivy_${trivy_version}_Linux-64bit.tar.gz"
        "grype:https://github.com/anchore/grype/releases/download/v${grype_version}/grype_${grype_version}_linux_amd64.tar.gz"
        "terraform:https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_amd64.zip"
    )

    for tool_info in "${tools[@]}"; do
        IFS=':' read -r tool_name download_url <<< "$tool_info"
        echo "Uploading $tool_name..."

        # Download the binary
        curl -L -o "/tmp/${tool_name}.tar.gz" "$download_url"

        # Calculate SHA256 hash
        local sha256_hash=$(shasum -a 256 "/tmp/${tool_name}.tar.gz" | cut -d' ' -f1)

        # Upload to CodeArtifact with timestamp version
        local timestamp=$(date +%Y%m%d%H%M%S)
        aws codeartifact publish-package-version \
            --domain $DOMAIN_NAME \
            --repository generic-store \
            --format generic \
            --namespace security-tools \
            --package $tool_name \
            --package-version "$timestamp" \
            --asset-name "${tool_name}.tar.gz" \
            --asset-content "/tmp/${tool_name}.tar.gz" \
            --asset-sha256 "$sha256_hash" \
            --region $AWS_REGION

        # Clean up
        rm "/tmp/${tool_name}.tar.gz"
        echo "✅ $tool_name uploaded"
    done

    echo "✅ Generic repository populated"
}

# Function to sync internal repository
sync_internal() {
    echo "🔄 Syncing internal repository..."

    # The internal repository automatically syncs from upstream repositories
    # when packages are requested. This is handled by CodeArtifact.
    echo "Internal repository will automatically sync from upstream repositories"
    echo "✅ Internal repository sync configured"
}

# Main execution
main() {
    echo "Starting repository population..."
    echo ""

    # Refresh authentication tokens first
    refresh_tokens
    echo ""

    # Populate repositories
    populate_npm
    echo ""

    # Refresh tokens before pip operations
    refresh_tokens
    populate_pip
    echo ""

    populate_maven
    echo ""

    # Refresh tokens before generic operations
    refresh_tokens
    populate_generic
    echo ""

    sync_internal
    echo ""

    echo "🎉 Repository population completed!"
    echo ""
    echo "Repository endpoints:"
    echo "  NPM: $(get_repository_endpoint "npm-store" "npm")"
    echo "  Pip: $(get_repository_endpoint "pip-store" "pypi")"
    echo "  Maven: $(get_repository_endpoint "maven-store" "maven")"
    echo "  Generic: $(get_repository_endpoint "generic-store" "generic")"
    echo "  Internal: $(get_repository_endpoint "internal-store" "generic")"
}

# Run main function
main "$@"
