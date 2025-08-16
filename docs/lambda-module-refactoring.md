# Lambda Module Refactoring

This document explains the refactoring from compute-fleet-specific Lambda implementation to a generic, reusable Lambda module.

## Why We Refactored

### Original Problem
The original implementation had Lambda-specific code embedded within the compute-fleet module:

```
terraform/modules/compute-fleet/
├── lambda/
│   ├── fleet_controller.py
│   └── requirements.txt
├── build_lambda.sh
├── main.tf
└── ...
```

### Issues with Original Approach
1. **Code Duplication**: Lambda functions are common across projects
2. **Maintenance Overhead**: Each module had its own Lambda implementation
3. **Inconsistent Patterns**: Different modules used different Lambda approaches
4. **Limited Reusability**: Lambda code was tied to specific modules

## New Generic Lambda Module

### Structure
```
terraform/modules/lambda/
├── src/                    # Source code directory
│   ├── fleet_controller.py # Fleet control function
│   └── requirements.txt    # Dependencies
├── build.sh               # Generic build script
├── main.tf                # Main Terraform configuration
├── variables.tf           # Input variables
├── outputs.tf             # Output values
└── README.md              # Documentation
```

### Key Features
1. **Reusable**: Can be used by any module that needs Lambda functions
2. **Flexible**: Supports various configurations (VPC, EventBridge, custom policies)
3. **Standardized**: Consistent patterns across all Lambda functions
4. **Maintainable**: Single place to update Lambda-related code

## Migration Guide

### Before (Compute-Fleet Specific)
```hcl
# In compute-fleet/main.tf
resource "aws_lambda_function" "fleet_controller" {
  filename         = data.archive_file.fleet_controller_zip.output_path
  function_name    = "${var.fleet_name}-controller"
  role            = aws_iam_role.lambda_role.arn
  handler         = "fleet_controller.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      FLEET_NAME = aws_codebuild_fleet.main.name
      TARGET_CAPACITY_ON  = var.target_capacity
      TARGET_CAPACITY_OFF = 0
    }
  }
}

# Build script and archive resources...
```

### After (Generic Module)
```hcl
# In compute-fleet/main.tf
module "fleet_controller" {
  source = "../lambda"

  function_name = "${var.fleet_name}-controller"
  handler_file  = "fleet_controller.py"
  handler       = "fleet_controller.lambda_handler"
  runtime       = "python3.9"
  timeout       = 300
  description   = "Lambda function to control CodeBuild fleet scaling"

  environment_variables = {
    FLEET_NAME = aws_codebuild_fleet.main.name
    TARGET_CAPACITY_ON  = var.target_capacity
    TARGET_CAPACITY_OFF = 0
  }

  create_role = false
  role_arn    = aws_iam_role.lambda_role.arn

  custom_policies = {
    fleet_control = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "codebuild:UpdateFleetScalingConfiguration",
            "codebuild:DescribeFleet"
          ]
          Resource = aws_codebuild_fleet.main.arn
        }
      ]
    })
  }
}
```

## Benefits of the New Approach

### 1. **Reusability**
- Any module can use the Lambda module
- Consistent patterns across projects
- Reduced code duplication

### 2. **Maintainability**
- Single place to update Lambda logic
- Easier to apply security patches
- Centralized dependency management

### 3. **Flexibility**
- Support for VPC configuration
- EventBridge integration
- Custom IAM policies
- Environment variables

### 4. **Standardization**
- Consistent build process
- Standardized IAM roles
- Uniform logging configuration

## Usage Examples

### Basic Lambda Function
```hcl
module "simple_lambda" {
  source = "./modules/lambda"

  function_name = "my-function"
  handler_file  = "main.py"
  handler       = "main.lambda_handler"
}
```

### Lambda with Dependencies
```hcl
module "lambda_with_deps" {
  source = "./modules/lambda"

  function_name = "my-function"
  handler_file  = "main.py"
  handler       = "main.lambda_handler"
  build_package = true  # Will install dependencies from requirements.txt
}
```

### Lambda with VPC
```hcl
module "vpc_lambda" {
  source = "./modules/lambda"

  function_name = "my-vpc-function"
  handler_file  = "main.py"
  handler       = "main.lambda_handler"

  vpc_config = {
    subnet_ids         = ["subnet-12345678"]
    security_group_ids = ["sg-12345678"]
  }
}
```

### Lambda with EventBridge Trigger
```hcl
module "scheduled_lambda" {
  source = "./modules/lambda"

  function_name = "my-scheduled-function"
  handler_file  = "main.py"
  handler       = "main.lambda_handler"

  event_rule = {
    description         = "Trigger every hour"
    schedule_expression = "rate(1 hour)"
  }
}
```

## Migration Steps

If you have existing Lambda functions in other modules:

1. **Move Source Code**: Move Lambda function code to `modules/lambda/src/`
2. **Update Module Calls**: Replace Lambda resources with module calls
3. **Configure Variables**: Set appropriate variables for your use case
4. **Test Deployment**: Verify the function works correctly
5. **Update Documentation**: Update any module-specific documentation

## Best Practices

1. **Use Descriptive Names**: Choose meaningful function names
2. **Organize Source Code**: Keep related functions in the same module
3. **Version Dependencies**: Pin dependency versions in requirements.txt
4. **Test Locally**: Test functions before deployment
5. **Monitor Performance**: Use CloudWatch metrics to optimize

## Future Enhancements

The generic Lambda module can be extended with:

1. **Layer Support**: For shared dependencies
2. **S3 Deployment**: For large packages
3. **Custom Runtimes**: Support for custom runtimes
4. **Testing Integration**: Built-in testing capabilities
5. **CI/CD Integration**: Automated deployment pipelines

This refactoring makes the codebase more maintainable, reusable, and follows infrastructure-as-code best practices.
