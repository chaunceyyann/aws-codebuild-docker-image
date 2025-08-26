#!/bin/bash

# Deployment script for AWS CodeBuild Docker Image with CodeArtifact
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
ECR_REPO_NAME=${ECR_REPO_NAME:-docker-image-4codebuild-repo}
CODEARTIFACT_DOMAIN=${CODEARTIFACT_DOMAIN:-security-tools-domain}

echo -e "${BLUE}🚀 AWS CodeBuild Docker Image Deployment${NC}"
echo "=========================================="
echo -e "Region: ${YELLOW}$AWS_REGION${NC}"
echo -e "ECR Repository: ${YELLOW}$ECR_REPO_NAME${NC}"
echo -e "CodeArtifact Domain: ${YELLOW}$CODEARTIFACT_DOMAIN${NC}"
echo ""

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}📋 Checking prerequisites...${NC}"

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI is not installed${NC}"
        exit 1
    fi

    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}❌ Terraform is not installed${NC}"
        exit 1
    fi

    # Check jq
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}❌ jq is not installed${NC}"
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}❌ AWS credentials not configured${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ All prerequisites met${NC}"
    echo ""
}

# Function to deploy Terraform infrastructure
deploy_infrastructure() {
    echo -e "${BLUE}🏗️  Deploying Terraform infrastructure...${NC}"

    cd terraform

    # Initialize Terraform
    echo "Initializing Terraform..."
    terraform init

    # Plan deployment
    echo "Planning deployment..."
    terraform plan \
        -var="aws_region=$AWS_REGION" \
        -var="ecr_repo_name=$ECR_REPO_NAME" \
        -var="codeartifact_domain_name=$CODEARTIFACT_DOMAIN"

    # Ask for confirmation
    read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⚠️  Deployment cancelled${NC}"
        exit 1
    fi

    # Apply deployment
    echo "Applying Terraform configuration..."
    terraform apply \
        -var="aws_region=$AWS_REGION" \
        -var="ecr_repo_name=$ECR_REPO_NAME" \
        -var="codeartifact_domain_name=$CODEARTIFACT_DOMAIN" \
        -auto-approve

    cd ..
    echo -e "${GREEN}✅ Infrastructure deployed successfully${NC}"
    echo ""
}

# Function to initialize CodeArtifact repositories
setup_codeartifact() {
    echo -e "${BLUE}📦 Setting up CodeArtifact repositories...${NC}"

    # Set environment variables
    export DOMAIN_NAME=$CODEARTIFACT_DOMAIN
    export AWS_REGION=$AWS_REGION
    export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

    # Make script executable and run
    chmod +x scripts/setup_codeartifact.sh
    ./scripts/setup_codeartifact.sh

    echo -e "${GREEN}✅ CodeArtifact repositories initialized${NC}"
    echo ""
}

# Function to verify deployment
verify_deployment() {
    echo -e "${BLUE}🔍 Verifying deployment...${NC}"

    # Check ECR repositories
    echo "Checking ECR repositories..."
    aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION &> /dev/null
    aws ecr describe-repositories --repository-names code-scanner-4codebuild-repo --region $AWS_REGION &> /dev/null

    # Check CodeArtifact domain
    echo "Checking CodeArtifact domain..."
    aws codeartifact describe-domain --domain $CODEARTIFACT_DOMAIN --region $AWS_REGION &> /dev/null

    # Check CodeBuild projects
    echo "Checking CodeBuild projects..."
    aws codebuild list-projects --region $AWS_REGION | grep -q "container-image-builder"

    echo -e "${GREEN}✅ Deployment verified successfully${NC}"
    echo ""
}

# Function to display next steps
show_next_steps() {
    echo -e "${BLUE}📋 Next Steps${NC}"
    echo "============="
    echo ""
    echo "1. Monitor the first build:"
    echo "   aws codebuild start-build --project-name container-image-builder --region $AWS_REGION"
    echo ""
    echo "2. Check build logs:"
    echo "   aws logs describe-log-groups --log-group-name-prefix '/aws/codebuild/' --region $AWS_REGION"
    echo ""
    echo "3. View CodeArtifact repositories:"
    echo "   aws codeartifact list-repositories-in-domain --domain $CODEARTIFACT_DOMAIN --region $AWS_REGION"
    echo ""
    echo "4. Monitor package updates:"
    echo "   aws logs describe-log-groups --log-group-name-prefix '/aws/lambda/' --region $AWS_REGION"
    echo ""
    echo "5. Use the Docker image in your CodeBuild projects:"
    echo "   $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest"
    echo ""
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
}

# Main execution
main() {
    check_prerequisites
    deploy_infrastructure
    setup_codeartifact
    verify_deployment
    show_next_steps
}

# Run main function
main "$@"
