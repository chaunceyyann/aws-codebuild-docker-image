# Generic Lambda Module

A reusable Terraform module for creating AWS Lambda functions with proper packaging, IAM roles, and optional EventBridge triggers.

## Features

- **Flexible Packaging**: Support for both simple Python files and complex packages with dependencies
- **Automatic IAM Role Creation**: Creates appropriate IAM roles with basic execution permissions
- **VPC Support**: Optional VPC configuration for Lambda functions
- **EventBridge Integration**: Optional EventBridge rules for scheduled or event-driven execution
- **CloudWatch Logging**: Automatic log group creation with configurable retention
- **Custom Policies**: Support for custom IAM policies
- **Build Automation**: Automated package building with dependency management

## Usage

### Basic Lambda Function

```hcl
module "my_lambda" {
  source = "./modules/lambda"

  function_name = "my-function"
  handler_file  = "main.py"
  handler       = "main.lambda_handler"

  environment_variables = {
    ENV = "production"
  }
}
```

### Lambda Function with Dependencies

```hcl
module "my_lambda" {
  source = "./modules/lambda"

  function_name = "my-function"
  handler_file  = "main.py"
  handler       = "main.lambda_handler"
  build_package = true  # This will build a package with dependencies

  environment_variables = {
    ENV = "production"
  }
}
```

### Lambda Function in Function Directory (Recommended for Multiple Functions)

```hcl
module "fleet_controller" {
  source = "./modules/lambda"

  function_name = "fleet-controller"
  function_directory = "fleet-controller"  # Organizes code in src/fleet-controller/
  handler_file  = "main.py"
  handler       = "main.lambda_handler"
  build_package = true
}
```

### Lambda Function with VPC

```hcl
module "my_lambda" {
  source = "./modules/lambda"

  function_name = "my-vpc-function"
  handler_file  = "main.py"
  handler       = "main.lambda_handler"

  vpc_config = {
    subnet_ids         = ["subnet-12345678", "subnet-87654321"]
    security_group_ids = ["sg-12345678"]
  }
}
```

### Lambda Function with EventBridge Trigger

```hcl
module "my_lambda" {
  source = "./modules/lambda"

  function_name = "my-scheduled-function"
  handler_file  = "main.py"
  handler       = "main.lambda_handler"

  event_rule = {
    description         = "Trigger Lambda every hour"
    schedule_expression = "rate(1 hour)"
  }
}
```

### Lambda Function with Custom IAM Policies

```hcl
module "my_lambda" {
  source = "./modules/lambda"

  function_name = "my-s3-function"
  handler_file  = "main.py"
  handler       = "main.lambda_handler"

  custom_policies = {
    s3_access = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject"
          ]
          Resource = "arn:aws:s3:::my-bucket/*"
        }
      ]
    })
  }
}
```

### Lambda Function with Existing IAM Role

```hcl
module "my_lambda" {
  source = "./modules/lambda"

  function_name = "my-function"
  handler_file  = "main.py"
  handler       = "main.lambda_handler"

  create_role = false
  role_arn    = "arn:aws:iam::123456789012:role/existing-role"
}
```

## Directory Structure

### Simple Structure (Single Function)
```
modules/lambda/
├── src/                    # Source code directory
│   ├── main.py            # Lambda function code
│   └── requirements.txt   # Python dependencies (optional)
├── build.sh               # Build script for packaging
├── main.tf                # Main Terraform configuration
├── variables.tf           # Input variables
├── outputs.tf             # Output values
└── README.md              # This file
```

### Organized Structure (Multiple Functions)
```
modules/lambda/
├── src/                           # Source code directory
│   ├── fleet-controller/          # Function-specific directory
│   │   ├── main.py               # Fleet controller function
│   │   └── requirements.txt      # Fleet controller dependencies
│   ├── data-processor/           # Another function
│   │   ├── main.py               # Data processor function
│   │   └── requirements.txt      # Data processor dependencies
│   └── utils/                    # Shared utilities
│       └── common.py             # Shared code
├── build.sh                      # Build script for packaging
├── main.tf                       # Main Terraform configuration
├── variables.tf                  # Input variables
├── outputs.tf                    # Output values
└── README.md                     # This file
```

## Source Code Organization

### Option 1: Simple Organization (Single Function)
Place your Lambda function code directly in the `src/` directory:

```
src/
├── main.py               # Main handler file
├── utils.py              # Utility functions
├── requirements.txt      # Python dependencies
└── config.py             # Configuration
```

### Option 2: Function Directory Organization (Multiple Functions)
Organize multiple functions in separate directories:

```
src/
├── fleet-controller/     # Fleet control function
│   ├── main.py          # Main handler
│   ├── fleet_utils.py   # Fleet-specific utilities
│   └── requirements.txt # Fleet dependencies
├── data-processor/      # Data processing function
│   ├── main.py          # Main handler
│   ├── processor.py     # Processing logic
│   └── requirements.txt # Processing dependencies
└── shared/              # Shared code (optional)
    └── common.py        # Common utilities
```

## Build Process

The module automatically builds deployment packages when `build_package = true`:

1. **Dependency Installation**: Installs packages from `requirements.txt`
2. **Source Copying**: Copies all Python files to build directory
3. **Package Creation**: Creates a ZIP file with all dependencies
4. **Validation**: Checks package size and content
5. **Deployment**: Uses the built package for Lambda deployment

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| function_name | Name of the Lambda function | `string` | n/a | yes |
| function_directory | Directory name for function source code | `string` | `null` | no |
| handler_file | Name of the handler file | `string` | `"main.py"` | no |
| handler | Lambda function handler | `string` | `"main.lambda_handler"` | no |
| runtime | Lambda function runtime | `string` | `"python3.9"` | no |
| timeout | Function timeout in seconds | `number` | `300` | no |
| memory_size | Function memory size in MB | `number` | `128` | no |
| description | Function description | `string` | `""` | no |
| build_package | Whether to build deployment package | `bool` | `true` | no |
| source_file | Path to source file (when build_package=false) | `string` | `null` | no |
| role_arn | IAM role ARN (if not creating one) | `string` | `null` | no |
| create_role | Whether to create IAM role | `bool` | `true` | no |
| environment_variables | Environment variables | `map(string)` | `{}` | no |
| vpc_config | VPC configuration | `object` | `null` | no |
| log_retention_days | CloudWatch log retention days | `number` | `14` | no |
| custom_policies | Custom IAM policies | `map(string)` | `{}` | no |
| event_rule | EventBridge rule configuration | `object` | `null` | no |
| tags | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| function_arn | ARN of the Lambda function |
| function_name | Name of the Lambda function |
| function_invoke_arn | Invocation ARN of the Lambda function |
| role_arn | ARN of the IAM role |
| role_name | Name of the IAM role |
| log_group_name | Name of the CloudWatch log group |
| log_group_arn | ARN of the CloudWatch log group |
| event_rule_arn | ARN of the EventBridge rule (if created) |
| event_rule_name | Name of the EventBridge rule (if created) |

## Examples

See the `examples/` directory for complete working examples:

- `examples/simple/` - Basic Lambda function
- `examples/with-dependencies/` - Lambda function with external dependencies
- `examples/with-vpc/` - Lambda function in VPC
- `examples/with-eventbridge/` - Lambda function with EventBridge trigger
- `examples/with-custom-policies/` - Lambda function with custom IAM policies

## Best Practices

1. **Use Descriptive Names**: Choose meaningful function names
2. **Organize Functions**: Use function directories for multiple functions
3. **Set Appropriate Timeouts**: Configure timeouts based on expected execution time
4. **Optimize Memory**: Higher memory allocation can improve performance
5. **Use Environment Variables**: Store configuration in environment variables
6. **Implement Proper Logging**: Use structured logging for better observability
7. **Handle Errors Gracefully**: Implement proper error handling in your code
8. **Test Locally**: Test your Lambda function locally before deployment

## Troubleshooting

### Common Issues

1. **Package Too Large**: If your package exceeds 50MB, consider using S3 for deployment
2. **Permission Errors**: Ensure the IAM role has necessary permissions
3. **VPC Issues**: Check subnet and security group configurations
4. **Build Failures**: Verify Python dependencies and build script execution

### Debugging

1. **Check CloudWatch Logs**: Review function logs for errors
2. **Validate Package**: Use the build script with `--validate` flag
3. **Test Locally**: Test the function code locally before deployment
4. **Check IAM Permissions**: Verify role permissions in AWS Console

## Contributing

When contributing to this module:

1. Follow the existing code style
2. Add tests for new features
3. Update documentation
4. Ensure backward compatibility
5. Test with different configurations
