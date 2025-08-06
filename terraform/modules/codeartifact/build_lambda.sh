#!/bin/bash

# Script to build Lambda deployment package with dependencies
set -e

echo "🔨 Building Lambda deployment package..."

# Create temporary directory for building
BUILD_DIR=$(mktemp -d)
echo "Build directory: $BUILD_DIR"

# Copy the Lambda function code
cp package_updater.py "$BUILD_DIR/index.py"

# Create requirements.txt for dependencies
cat > "$BUILD_DIR/requirements.txt" << EOF
requests==2.31.0
boto3==1.34.0
botocore==1.34.0
EOF

# Install dependencies to the build directory
echo "📦 Installing dependencies..."
pip install -r "$BUILD_DIR/requirements.txt" -t "$BUILD_DIR"

# Remove unnecessary files to reduce package size
echo "🧹 Cleaning up package..."
cd "$BUILD_DIR"
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true

# Create the deployment package
echo "📦 Creating deployment package..."
zip -r package_updater.zip . -x "requirements.txt"

# Move the package to the module directory
mv package_updater.zip /tmp/package_updater.zip

# Clean up build directory
rm -rf "$BUILD_DIR"

echo "✅ Lambda deployment package created: /tmp/package_updater.zip"
