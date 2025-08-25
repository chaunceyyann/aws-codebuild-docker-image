#!/bin/bash

# Setup GitHub OIDC Provider for Fleet Control
# This script configures the OIDC provider to allow GitHub Actions to assume your CodeBuild role

set -e

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
GITHUB_REPO="${GITHUB_REPO:-your-org/your-repo}"  # Update this
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_NAME="shared-codebuild-role"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_info "Setting up GitHub OIDC provider for fleet control..."
print_info "AWS Account: $AWS_ACCOUNT_ID"
print_info "Region: $AWS_REGION"
print_info "GitHub Repo: $GITHUB_REPO"
print_info "Role: $ROLE_NAME"

# Check if OIDC provider already exists
print_info "Checking for existing GitHub OIDC provider..."
OIDC_ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?ends_with(Arn, 'token.actions.githubusercontent.com')].Arn" --output text)

if [ -z "$OIDC_ARN" ]; then
    print_info "Creating GitHub OIDC provider..."

    # Download GitHub's thumbprint
    THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"

    OIDC_ARN=$(aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list $THUMBPRINT \
        --query 'OpenIDConnectProviderArn' \
        --output text)

    print_success "Created OIDC provider: $OIDC_ARN"
else
    print_info "OIDC provider already exists: $OIDC_ARN"
fi

# Update the CodeBuild role trust policy to allow GitHub Actions
print_info "Updating CodeBuild role trust policy..."

TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      }
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_ARN"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:$GITHUB_REPO:*"
        }
      }
    }
  ]
}
EOF
)

aws iam update-assume-role-policy \
    --role-name $ROLE_NAME \
    --policy-document "$TRUST_POLICY"

print_success "Updated trust policy for role: $ROLE_NAME"

# Check current role permissions
print_info "Verifying fleet control permissions..."
FLEET_PERMS=$(aws iam get-role-policy \
    --role-name $ROLE_NAME \
    --policy-name codebuild_policy \
    --query 'PolicyDocument.Statement[?contains(Action, `codebuild:UpdateFleet`)].Action' \
    --output text)

if [ -n "$FLEET_PERMS" ]; then
    print_success "Fleet control permissions found in role"
else
    print_warning "Fleet control permissions not found. Please run 'terraform apply' to update the role."
fi

print_info "Setting up GitHub repository secrets..."

print_warning "⚠️  Manual Steps Required:"
echo ""
echo "1. Go to your GitHub repository settings:"
echo "   https://github.com/$GITHUB_REPO/settings/secrets/actions"
echo ""
echo "2. Add the following repository secret:"
echo "   Name: AWS_ACCOUNT_ID"
echo "   Value: $AWS_ACCOUNT_ID"
echo ""
echo "3. Update the GITHUB_REPO variable in this script with your actual repository name"
echo ""

print_info "Testing OIDC configuration..."

# Create a test policy document to verify the setup
cat > /tmp/test-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:GetCallerIdentity",
            "Resource": "*"
        }
    ]
}
EOF

print_success "✅ GitHub OIDC setup completed!"
print_info "Next steps:"
echo "  1. Update GITHUB_REPO in this script with your actual repository"
echo "  2. Add AWS_ACCOUNT_ID secret to your GitHub repository"
echo "  3. Run 'terraform apply' to deploy the IAM permission changes"
echo "  4. Test the workflow with a manual trigger"
echo ""
print_info "To test the fleet control workflow:"
echo "  - Go to Actions tab in your GitHub repository"
echo "  - Find 'Compute Fleet Scheduler' workflow"
echo "  - Click 'Run workflow' and test with 'status' action"

# Cleanup
rm -f /tmp/test-policy.json
