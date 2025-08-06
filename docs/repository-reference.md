# CodeArtifact Repository Reference

## Quick Overview

| Repository | Type | Purpose | External Connection | Usage |
|------------|------|---------|-------------------|-------|
| **npm-store** | npm | Node.js packages | npmjs | `npm install` |
| **pip-store** | pypi | Python packages | PyPI | `pip install` |
| **maven-store** | maven | Java packages | Maven Central | `mvn install` |
| **generic-store** | generic | Binary tools | None | Manual upload |
| **internal-store** | generic | Aggregated access | All above | All package types |

## Repository Details

### 1. npm-store
**Purpose**: Node.js and JavaScript packages
**External Connection**: npmjs (public npm registry)
**Common Packages**: npm, node, typescript, eslint, jest, react, vue, angular

**Usage**:
```bash
# Configure npm (recommended method)
aws codeartifact login --tool npm --repository npm-store --domain $DOMAIN_NAME --region $AWS_REGION

# Alternative manual method
npm config set registry $NPM_ENDPOINT
npm config set //$DOMAIN:_authToken $TOKEN

# Install packages
npm install lodash
npm install react@latest
```

### 2. pip-store
**Purpose**: Python packages
**External Connection**: PyPI (Python Package Index)
**Common Packages**: checkov, bandit, safety, pip-audit, semgrep, requests, boto3, pandas

**Usage**:
```bash
# Configure pip
pip config set global.index-url https://aws:$TOKEN@$PIP_ENDPOINT/simple/

# Install packages
pip install checkov
pip install requests
```

### 3. maven-store
**Purpose**: Java packages and dependencies
**External Connection**: Maven Central
**Common Packages**: Spring Boot, Apache Commons, JUnit, Mockito

**Usage**:
```bash
# Configure Maven settings.xml
# Then use Maven normally
mvn clean install
mvn dependency:resolve
```

### 4. generic-store
**Purpose**: Binary tools and custom packages
**External Connection**: None (manual uploads)
**Common Tools**: trivy, grype, terraform, tflint, semgrep

**Usage**:
```bash
# Upload binary tools
aws codeartifact upload-package-version-asset \
    --domain $DOMAIN_NAME \
    --repository generic-store \
    --format generic \
    --namespace security-tools \
    --package trivy \
    --package-version "1.0.0" \
    --asset-name "trivy-1.0.0.tar.gz" \
    --asset file://trivy.tar.gz \
    --region $AWS_REGION

# Download tools
curl -H "Authorization: Bearer $TOKEN" \
     "$GENERIC_ENDPOINT/security-tools/trivy/1.0.0/trivy-1.0.0.tar.gz"
```

### 5. internal-store
**Purpose**: Aggregated access to all repositories
**External Connection**: All upstream repositories
**Usage**: Single endpoint for all package types

**Usage**:
```bash
# Configure to use internal repository for all package types
# This provides access to packages from all other repositories
```

## Quick Commands

### Get Repository Endpoints
```bash
DOMAIN_NAME="security-tools-domain"
AWS_REGION="us-east-1"

# Get all endpoints
NPM_ENDPOINT=$(aws codeartifact get-repository-endpoint \
    --domain $DOMAIN_NAME --repository npm-store --format npm \
    --region $AWS_REGION --query repositoryEndpoint --output text)

PIP_ENDPOINT=$(aws codeartifact get-repository-endpoint \
    --domain $DOMAIN_NAME --repository pip-store --format pypi \
    --region $AWS_REGION --query repositoryEndpoint --output text)

MAVEN_ENDPOINT=$(aws codeartifact get-repository-endpoint \
    --domain $DOMAIN_NAME --repository maven-store --format maven \
    --region $AWS_REGION --query repositoryEndpoint --output text)

GENERIC_ENDPOINT=$(aws codeartifact get-repository-endpoint \
    --domain $DOMAIN_NAME --repository generic-store --format generic \
    --region $AWS_REGION --query repositoryEndpoint --output text)

INTERNAL_ENDPOINT=$(aws codeartifact get-repository-endpoint \
    --domain $DOMAIN_NAME --repository internal-store --format generic \
    --region $AWS_REGION --query repositoryEndpoint --output text)
```

### Get Authorization Token
```bash
TOKEN=$(aws codeartifact get-authorization-token \
    --domain $DOMAIN_NAME \
    --region $AWS_REGION \
    --query authorizationToken \
    --output text)
```

### List Packages
```bash
# List npm packages
aws codeartifact list-packages \
    --domain $DOMAIN_NAME \
    --repository npm-store \
    --format npm \
    --region $AWS_REGION

# List pip packages
aws codeartifact list-packages \
    --domain $DOMAIN_NAME \
    --repository pip-store \
    --format pypi \
    --region $AWS_REGION

# List generic packages
aws codeartifact list-packages \
    --domain $DOMAIN_NAME \
    --repository generic-store \
    --format generic \
    --region $AWS_REGION
```

## Package Population Status

### ✅ Ready to Use
- **npm-store**: Configure npm and install packages
- **pip-store**: Configure pip and install packages
- **generic-store**: Upload binary tools manually

### 🔄 Automatic Population
- **maven-store**: Configure Maven settings.xml
- **internal-store**: Automatically syncs from upstream

### 🤖 Automated Updates
- Lambda function runs daily to update security tools
- Checks for new versions of trivy, grype, terraform, etc.
- Automatically uploads new versions to generic-store

## Integration Examples

### Docker Image Integration
```dockerfile
# In your Dockerfile
RUN aws codeartifact get-authorization-token \
    --domain security-tools-domain \
    --region us-east-1 \
    --query authorizationToken --output text > /tmp/token && \
    pip config set global.index-url \
    https://aws:$(cat /tmp/token)@security-tools-domain-{ACCOUNT_ID}.d.codeartifact.us-east-1.amazonaws.com/pypi/pip-store/simple/ && \
    rm /tmp/token

RUN pip install checkov bandit
```

### CI/CD Pipeline Integration
```yaml
# In your buildspec.yml or GitHub Actions
- name: Configure CodeArtifact
  run: |
    TOKEN=$(aws codeartifact get-authorization-token \
        --domain security-tools-domain \
        --region us-east-1 \
        --query authorizationToken --output text)
    pip config set global.index-url \
        https://aws:$TOKEN@security-tools-domain-{ACCOUNT_ID}.d.codeartifact.us-east-1.amazonaws.com/pypi/pip-store/simple/

- name: Install packages
  run: |
    pip install checkov bandit
```

### Local Development
```bash
# Add to your shell profile (.bashrc, .zshrc, etc.)
export CODEARTIFACT_DOMAIN="security-tools-domain"
export AWS_REGION="us-east-1"

# Function to configure CodeArtifact
configure_codeartifact() {
    local token=$(aws codeartifact get-authorization-token \
        --domain $CODEARTIFACT_DOMAIN \
        --region $AWS_REGION \
        --query authorizationToken --output text)

    # Configure npm
    npm config set registry https://$CODEARTIFACT_DOMAIN-{ACCOUNT_ID}.d.codeartifact.$AWS_REGION.amazonaws.com/npm/npm-store/
    npm config set //$CODEARTIFACT_DOMAIN-{ACCOUNT_ID}.d.codeartifact.$AWS_REGION.amazonaws.com/npm/npm-store/:_authToken $token

    # Configure pip
    pip config set global.index-url https://aws:$token@$CODEARTIFACT_DOMAIN-{ACCOUNT_ID}.d.codeartifact.$AWS_REGION.amazonaws.com/pypi/pip-store/simple/

    echo "CodeArtifact configured!"
}
```

## Monitoring and Maintenance

### Check Repository Usage
```bash
# Monitor storage usage
aws codeartifact describe-domain \
    --domain $DOMAIN_NAME \
    --region $AWS_REGION

# Check Lambda function logs
aws logs describe-log-groups \
    --log-group-name-prefix "/aws/lambda/security-tools-domain"
```

### Clean Up Old Packages
```bash
# List package versions
aws codeartifact list-package-versions \
    --domain $DOMAIN_NAME \
    --repository generic-store \
    --format generic \
    --package trivy \
    --region $AWS_REGION

# Delete old versions (if needed)
aws codeartifact delete-package-versions \
    --domain $DOMAIN_NAME \
    --repository generic-store \
    --format generic \
    --package trivy \
    --versions '["1.0.0"]' \
    --region $AWS_REGION
```
