# Lambda Source Code Management

This document explains the best practices for organizing and managing Lambda function source code in the generic Lambda module.

## Problem: Duplicate Source Files

When we initially created the generic Lambda module, we had duplicate `fleet_controller.py` files:

```
terraform/modules/compute-fleet/fleet_controller.py          # ❌ Duplicate
terraform/modules/lambda/src/fleet_controller.py            # ❌ Duplicate
```

This created confusion and maintenance issues.

## Solution: Organized Function Directories

We've implemented a better organization system using function-specific directories:

```
terraform/modules/lambda/src/
├── fleet-controller/          # ✅ Function-specific directory
│   ├── main.py               # Fleet controller function
│   └── requirements.txt      # Fleet controller dependencies
├── data-processor/           # Another function (example)
│   ├── main.py               # Data processor function
│   └── requirements.txt      # Data processor dependencies
└── shared/                   # Shared utilities (optional)
    └── common.py             # Common code
```

## Best Practices for Lambda Source Management

### 1. **Use Function Directories for Multiple Functions**

When you have multiple Lambda functions, organize them in separate directories:

```hcl
# Fleet controller function
module "fleet_controller" {
  source = "./modules/lambda"

  function_name = "fleet-controller"
  function_directory = "fleet-controller"  # Organizes in src/fleet-controller/
  handler_file  = "main.py"
  handler       = "main.lambda_handler"
}

# Data processor function
module "data_processor" {
  source = "./modules/lambda"

  function_name = "data-processor"
  function_directory = "data-processor"    # Organizes in src/data-processor/
  handler_file  = "main.py"
  handler       = "main.lambda_handler"
}
```

### 2. **Use Simple Structure for Single Functions**

For projects with only one Lambda function, use the simple structure:

```hcl
module "my_lambda" {
  source = "./modules/lambda"

  function_name = "my-function"
  handler_file  = "main.py"        # No function_directory needed
  handler       = "main.lambda_handler"
}
```

### 3. **Standardize File Names**

Use consistent naming conventions:

- **Main handler**: Always use `main.py` as the handler file
- **Requirements**: Always use `requirements.txt` for dependencies
- **Utilities**: Use descriptive names like `fleet_utils.py`, `processor.py`

### 4. **Organize Related Functions Together**

Group related functions in the same module:

```
src/
├── fleet-controller/          # Fleet management functions
│   ├── main.py               # Main fleet controller
│   ├── fleet_utils.py        # Fleet utilities
│   └── requirements.txt      # Fleet dependencies
├── monitoring/               # Monitoring functions
│   ├── main.py               # Main monitoring function
│   ├── metrics.py            # Metrics collection
│   └── requirements.txt      # Monitoring dependencies
└── shared/                   # Shared code
    └── common.py             # Common utilities
```

## Directory Structure Examples

### Example 1: Simple Project (Single Function)
```
terraform/modules/lambda/
├── src/
│   ├── main.py               # Single Lambda function
│   └── requirements.txt      # Dependencies
├── build.sh
├── main.tf
└── README.md
```

### Example 2: Medium Project (Multiple Related Functions)
```
terraform/modules/lambda/
├── src/
│   ├── fleet-controller/     # Fleet management
│   │   ├── main.py
│   │   └── requirements.txt
│   ├── fleet-monitor/        # Fleet monitoring
│   │   ├── main.py
│   │   └── requirements.txt
│   └── shared/               # Shared utilities
│       └── common.py
├── build.sh
├── main.tf
└── README.md
```

### Example 3: Complex Project (Multiple Unrelated Functions)
```
terraform/modules/lambda/
├── src/
│   ├── fleet-controller/     # Fleet management
│   │   ├── main.py
│   │   └── requirements.txt
│   ├── data-processor/       # Data processing
│   │   ├── main.py
│   │   └── requirements.txt
│   ├── notification-sender/  # Notifications
│   │   ├── main.py
│   │   └── requirements.txt
│   └── shared/               # Shared utilities
│       ├── common.py
│       └── config.py
├── build.sh
├── main.tf
└── README.md
```

## Migration Guide

### From Duplicate Files to Organized Structure

1. **Remove Duplicates**: Delete duplicate files from other modules
2. **Create Function Directory**: Create a directory for each function
3. **Move Source Code**: Move function code to appropriate directories
4. **Update Module Calls**: Update Terraform configurations to use `function_directory`
5. **Test Deployment**: Verify functions work correctly

### Example Migration

**Before (Duplicate Files)**:
```
terraform/modules/compute-fleet/fleet_controller.py          # ❌ Remove this
terraform/modules/lambda/src/fleet_controller.py            # ❌ Remove this
```

**After (Organized Structure)**:
```
terraform/modules/lambda/src/fleet-controller/main.py       # ✅ Keep this
```

**Before (Module Configuration)**:
```hcl
module "fleet_controller" {
  source = "../lambda"
  function_name = "fleet-controller"
  handler_file  = "fleet_controller.py"    # ❌ Old approach
  handler       = "fleet_controller.lambda_handler"
}
```

**After (Module Configuration)**:
```hcl
module "fleet_controller" {
  source = "../lambda"
  function_name = "fleet-controller"
  function_directory = "fleet-controller"   # ✅ New approach
  handler_file  = "main.py"
  handler       = "main.lambda_handler"
}
```

## Benefits of Organized Structure

### 1. **No More Duplicates**
- Single source of truth for each function
- Eliminates confusion and maintenance issues
- Prevents version drift between copies

### 2. **Better Organization**
- Clear separation of concerns
- Easy to find and maintain functions
- Scalable for multiple functions

### 3. **Improved Maintainability**
- Each function has its own directory
- Dependencies are clearly separated
- Easier to add new functions

### 4. **Better Development Experience**
- IDE support for each function
- Clear file structure
- Easy to navigate and understand

## Best Practices Summary

1. **Use Function Directories**: Organize multiple functions in separate directories
2. **Standardize Names**: Use `main.py` and `requirements.txt` consistently
3. **Group Related Functions**: Keep related functions together
4. **Avoid Duplicates**: Never have duplicate source files
5. **Use Descriptive Names**: Choose meaningful function and directory names
6. **Document Structure**: Keep documentation updated with current structure
7. **Test Changes**: Always test after reorganizing code

## Common Patterns

### Pattern 1: Single Function
```hcl
function_directory = null  # Use simple structure
handler_file = "main.py"
```

### Pattern 2: Multiple Functions
```hcl
function_directory = "function-name"  # Use organized structure
handler_file = "main.py"
```

### Pattern 3: Shared Code
```
src/
├── function1/
│   ├── main.py
│   └── requirements.txt
├── function2/
│   ├── main.py
│   └── requirements.txt
└── shared/
    └── common.py
```

This approach ensures clean, maintainable, and scalable Lambda function organization.
