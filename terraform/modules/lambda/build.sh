#!/bin/bash

# Build script for Lambda function with dependencies
# This script creates a proper deployment package for the Lambda function

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAMBDA_DIR="${SCRIPT_DIR}/src"
BUILD_DIR="${SCRIPT_DIR}/build"
DIST_DIR="${SCRIPT_DIR}/dist"
FUNCTION_NAME="${FUNCTION_NAME:-lambda-function}"
FUNCTION_DIRECTORY="${FUNCTION_DIRECTORY:-}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check if Python is available
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed or not in PATH"
        exit 1
    fi

    # Check if pip is available
    if ! command -v pip3 &> /dev/null; then
        print_error "pip3 is not installed or not in PATH"
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Function to clean build directories
clean_build() {
    print_info "Cleaning build directories..."

    rm -rf "${BUILD_DIR}"
    rm -rf "${DIST_DIR}"

    print_success "Build directories cleaned"
}

# Function to create build directories
create_directories() {
    print_info "Creating build directories..."

    mkdir -p "${BUILD_DIR}"
    mkdir -p "${DIST_DIR}"

    print_success "Build directories created"
}

# Function to install dependencies
install_dependencies() {
    print_info "Installing dependencies..."

    local requirements_file
    if [ -n "$FUNCTION_DIRECTORY" ]; then
        requirements_file="${LAMBDA_DIR}/${FUNCTION_DIRECTORY}/requirements.txt"
    else
        requirements_file="${LAMBDA_DIR}/requirements.txt"
    fi

    if [ -f "$requirements_file" ]; then
        pip3 install -r "$requirements_file" -t "${BUILD_DIR}" --no-cache-dir
        print_success "Dependencies installed from $requirements_file"
    else
        print_warning "No requirements.txt found at $requirements_file, skipping dependency installation"
    fi
}

# Function to copy source code
copy_source() {
    print_info "Copying source code..."

    if [ -n "$FUNCTION_DIRECTORY" ]; then
        cp "${LAMBDA_DIR}/${FUNCTION_DIRECTORY}"/*.py "${BUILD_DIR}/" 2>/dev/null || true
        print_success "Source code copied from ${LAMBDA_DIR}/${FUNCTION_DIRECTORY}"
    else
        cp "${LAMBDA_DIR}"/*.py "${BUILD_DIR}/" 2>/dev/null || true
        print_success "Source code copied from ${LAMBDA_DIR}"
    fi
}

# Function to create deployment package
create_package() {
    print_info "Creating deployment package..."

    cd "${BUILD_DIR}"
    zip -r "${DIST_DIR}/${FUNCTION_NAME}.zip" . -x "*.pyc" "__pycache__/*" "*.pyo" "*.pyd" ".pytest_cache/*" "*.egg-info/*"
    cd - > /dev/null

    print_success "Deployment package created: ${DIST_DIR}/${FUNCTION_NAME}.zip"
}

# Function to show package info
show_package_info() {
    print_info "Package information:"
    echo "  Size: $(du -h "${DIST_DIR}/${FUNCTION_NAME}.zip" | cut -f1)"
    echo "  Location: ${DIST_DIR}/${FUNCTION_NAME}.zip"

    print_info "Package contents:"
    unzip -l "${DIST_DIR}/${FUNCTION_NAME}.zip" | head -20
}

# Function to validate package
validate_package() {
    print_info "Validating package..."

    # Check if the main handler file is present
    if ! unzip -l "${DIST_DIR}/${FUNCTION_NAME}.zip" | grep -q "\.py$"; then
        print_error "No Python files found in package"
        exit 1
    fi

    # Check package size (Lambda has a 50MB limit for direct upload)
    PACKAGE_SIZE=$(stat -f%z "${DIST_DIR}/${FUNCTION_NAME}.zip" 2>/dev/null || stat -c%s "${DIST_DIR}/${FUNCTION_NAME}.zip" 2>/dev/null || echo "0")
    MAX_SIZE=52428800  # 50MB in bytes

    if [ "$PACKAGE_SIZE" -gt "$MAX_SIZE" ]; then
        print_warning "Package size ($(numfmt --to=iec $PACKAGE_SIZE)) exceeds Lambda direct upload limit (50MB)"
        print_warning "Consider using S3 for deployment or reducing dependencies"
    else
        print_success "Package size is within limits"
    fi

    print_success "Package validation passed"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -c, --clean     Clean build directories before building"
    echo "  -v, --validate  Validate the package after building"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Build package"
    echo "  $0 --clean      # Clean and build package"
    echo "  $0 --validate   # Build and validate package"
}

# Main function
main() {
    local clean_build_flag=false
    local validate_flag=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--clean)
                clean_build_flag=true
                shift
                ;;
            -v|--validate)
                validate_flag=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    print_info "Starting Lambda function build process..."

    # Check prerequisites
    check_prerequisites

    # Clean build if requested
    if [ "$clean_build_flag" = true ]; then
        clean_build
    fi

    # Create directories
    create_directories

    # Install dependencies
    install_dependencies

    # Copy source code
    copy_source

    # Create deployment package
    create_package

    # Show package info
    show_package_info

    # Validate package if requested
    if [ "$validate_flag" = true ]; then
        validate_package
    fi

    print_success "Lambda function build completed successfully!"
    print_info "Deployment package ready at: ${DIST_DIR}/${FUNCTION_NAME}.zip"
}

# Run main function with all arguments
main "$@"
