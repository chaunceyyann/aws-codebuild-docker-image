# Populating CodeArtifact Repositories

This guide explains how to populate your CodeArtifact repositories with packages from public sources.

## Overview

Your CodeArtifact setup includes 5 repositories:

1. **npm-store** - Node.js packages (connected to npmjs)
2. **pip-store** - Python packages (connected to PyPI)
3. **maven-store** - Java packages (connected to Maven Central)
4. **generic-store** - Binary tools and custom packages
5. **internal-store** - Aggregated repository with upstream connections

## Method 1: Automated Population (Recommended)

### Quick Start
```bash
# Make sure you have the required tools
which npm pip jq curl

# Run the automated population script
./scripts/populate_repositories.sh
```

### What the Script Does
- Configures npm and pip to use CodeArtifact
- Downloads and uploads popular packages to each repository
- Sets up binary tools in the generic repository
- Provides configuration instructions for Maven

## Method 2: Manual Population

### Step 1: Get Repository Information

```bash
# Set your domain name
DOMAIN_NAME="security-tools-domain"
AWS_REGION="us-east-1"

# Get authorization token
TOKEN=$(aws codeartifact get-authorization-token \
    --domain $DOMAIN_NAME \
    --region $AWS_REGION \
    --query authorizationToken \
    --output text)

# Get repository endpoints
NPM_ENDPOINT=$(aws codeartifact get-repository-endpoint \
    --domain $DOMAIN_NAME \
    --repository npm-store \
    --format npm \
    --region $AWS_REGION \
    --query repositoryEndpoint \
    --output text)

PIP_ENDPOINT=$(aws codeartifact get-repository-endpoint \
    --domain $DOMAIN_NAME \
    --repository pip-store \
    --format pypi \
    --region $AWS_REGION \
    --query repositoryEndpoint \
    --output text)
```

### Step 2: Populate npm Repository

```bash
# Configure npm to use CodeArtifact (recommended method)
aws codeartifact login --tool npm --repository npm-store --domain $DOMAIN_NAME --region $AWS_REGION

# Alternative manual method
npm config set registry $NPM_ENDPOINT
npm config set //$DOMAIN:_authToken $TOKEN

# Install packages (they'll be cached in CodeArtifact)
npm install npm@latest
npm install yarn@latest
npm install typescript@latest
npm install eslint@latest
npm install jest@latest
npm install webpack@latest
npm install react@latest
npm install vue@latest
npm install angular@latest
npm install lodash@latest
npm install express@latest
npm install axios@latest
```

### Step 3: Populate pip Repository

```bash
# Configure pip to use CodeArtifact
pip config set global.index-url https://aws:$TOKEN@$PIP_ENDPOINT/simple/
pip config set global.extra-index-url https://pypi.org/simple/

# Install packages (they'll be cached in CodeArtifact)
pip install checkov
pip install bandit
pip install safety
pip install pip-audit
pip install semgrep
pip install black
pip install flake8
pip install mypy
pip install pytest
pip install requests
pip install boto3
pip install pandas
pip install numpy
pip install fastapi
pip install django
pip install flask
```

### Step 4: Populate Generic Repository

```bash
# Get latest versions
TRIVY_VERSION=$(curl -s "https://api.github.com/repos/aquasecurity/trivy/releases/latest" | jq -r '.tag_name' | sed 's/v//')
GRYPE_VERSION=$(curl -s "https://api.github.com/repos/anchore/grype/releases/latest" | jq -r '.tag_name' | sed 's/v//')
TERRAFORM_VERSION=$(curl -s "https://checkpoint-api.hashicorp.com/v1/check/terraform" | jq -r '.current_version')

# Download and upload Trivy
curl -L -o /tmp/trivy.tar.gz "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
aws codeartifact upload-package-version-asset \
    --domain $DOMAIN_NAME \
    --repository generic-store \
    --format generic \
    --namespace security-tools \
    --package trivy \
    --package-version $TRIVY_VERSION \
    --asset-name "trivy-${TRIVY_VERSION}.tar.gz" \
    --asset file:///tmp/trivy.tar.gz \
    --region $AWS_REGION

# Download and upload Grype
curl -L -o /tmp/grype.tar.gz "https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/grype_${GRYPE_VERSION}_linux_amd64.tar.gz"
aws codeartifact upload-package-version-asset \
    --domain $DOMAIN_NAME \
    --repository generic-store \
    --format generic \
    --namespace security-tools \
    --package grype \
    --package-version $GRYPE_VERSION \
    --asset-name "grype-${GRYPE_VERSION}.tar.gz" \
    --asset file:///tmp/grype.tar.gz \
    --region $AWS_REGION

# Download and upload Terraform
curl -L -o /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
aws codeartifact upload-package-version-asset \
    --domain $DOMAIN_NAME \
    --repository generic-store \
    --format generic \
    --namespace security-tools \
    --package terraform \
    --package-version $TERRAFORM_VERSION \
    --asset-name "terraform-${TERRAFORM_VERSION}.zip" \
    --asset file:///tmp/terraform.zip \
    --region $AWS_REGION

# Clean up
rm /tmp/trivy.tar.gz /tmp/grype.tar.gz /tmp/terraform.zip
```

### Step 5: Configure Maven (Optional)

```bash
# Get Maven endpoint
MAVEN_ENDPOINT=$(aws codeartifact get-repository-endpoint \
    --domain $DOMAIN_NAME \
    --repository maven-store \
    --format maven \
    --region $AWS_REGION \
    --query repositoryEndpoint \
    --output text)

# Create Maven settings.xml
cat > ~/.m2/settings.xml << EOF
<settings>
  <servers>
    <server>
      <id>codeartifact</id>
      <username>aws</username>
      <password>${TOKEN}</password>
    </server>
  </servers>
  <profiles>
    <profile>
      <id>codeartifact</id>
      <repositories>
        <repository>
          <id>codeartifact</id>
          <url>${MAVEN_ENDPOINT}</url>
        </repository>
      </repositories>
    </profile>
  </profiles>
  <activeProfiles>
    <activeProfile>codeartifact</activeProfile>
  </activeProfiles>
</settings>
EOF

# Test Maven configuration
mvn dependency:resolve
```

## Method 3: Using the Lambda Function

The Lambda function created in the Terraform setup will automatically:

1. Check for new versions of security tools daily
2. Download and upload them to the appropriate repositories
3. Keep your repositories up-to-date

### Manual Trigger
```bash
# Trigger the Lambda function manually
aws lambda invoke \
    --function-name security-tools-domain-package-updater \
    --region us-east-1 \
    response.json

# Check the response
cat response.json
```

## Method 4: Package Manager Integration

### For npm Projects
```bash
# Configure npm to use CodeArtifact
npm config set registry $NPM_ENDPOINT
npm config set //$NPM_ENDPOINT:_authToken $TOKEN

# Install packages (they'll be cached automatically)
npm install
```

### For Python Projects
```bash
# Configure pip to use CodeArtifact
pip config set global.index-url https://aws:$TOKEN@$PIP_ENDPOINT/simple/

# Install packages (they'll be cached automatically)
pip install -r requirements.txt
```

### For Maven Projects
```bash
# Use the Maven settings.xml created above
mvn clean install
```

## Verification

### Check Repository Contents
```bash
# List packages in npm repository
aws codeartifact list-packages \
    --domain $DOMAIN_NAME \
    --repository npm-store \
    --format npm \
    --region $AWS_REGION

# List packages in pip repository
aws codeartifact list-packages \
    --domain $DOMAIN_NAME \
    --repository pip-store \
    --format pypi \
    --region $AWS_REGION

# List packages in generic repository
aws codeartifact list-packages \
    --domain $DOMAIN_NAME \
    --repository generic-store \
    --format generic \
    --region $AWS_REGION
```

### Test Package Installation
```bash
# Test npm package installation
npm install lodash --registry $NPM_ENDPOINT

# Test pip package installation
pip install requests --index-url https://aws:$TOKEN@$PIP_ENDPOINT/simple/
```

## Repository Endpoints

After population, your repositories will be available at:

- **NPM**: `https://security-tools-domain-{ACCOUNT_ID}.d.codeartifact.{REGION}.amazonaws.com/npm/npm-store/`
- **Pip**: `https://security-tools-domain-{ACCOUNT_ID}.d.codeartifact.{REGION}.amazonaws.com/pypi/pip-store/`
- **Maven**: `https://security-tools-domain-{ACCOUNT_ID}.d.codeartifact.{REGION}.amazonaws.com/maven/maven-store/`
- **Generic**: `https://security-tools-domain-{ACCOUNT_ID}.d.codeartifact.{REGION}.amazonaws.com/generic/generic-store/`
- **Internal**: `https://security-tools-domain-{ACCOUNT_ID}.d.codeartifact.{REGION}.amazonaws.com/generic/internal-store/`

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   ```bash
   # Check if token is valid
   aws codeartifact get-authorization-token --domain $DOMAIN_NAME --region $AWS_REGION
   ```

2. **Package Not Found**
   ```bash
   # Check if package exists in repository
   aws codeartifact list-package-versions \
       --domain $DOMAIN_NAME \
       --repository pip-store \
       --format pypi \
       --package checkov \
       --region $AWS_REGION
   ```

3. **Network Issues**
   ```bash
   # Test connectivity to repository
   curl -H "Authorization: Bearer $TOKEN" $PIP_ENDPOINT/simple/
   ```

### Best Practices

1. **Use the automated script** for initial population
2. **Configure CI/CD pipelines** to use CodeArtifact repositories
3. **Monitor the Lambda function** for automatic updates
4. **Regularly check repository usage** and clean up unused packages
5. **Use the internal repository** for aggregated access to all packages

## Next Steps

After populating your repositories:

1. **Configure your Docker images** to use CodeArtifact (see `container-codebuild-image/Dockerfile`)
2. **Update your CI/CD pipelines** to use the CodeArtifact endpoints
3. **Monitor package usage** and costs
4. **Set up alerts** for the Lambda function
5. **Consider adding custom packages** to the generic repository
