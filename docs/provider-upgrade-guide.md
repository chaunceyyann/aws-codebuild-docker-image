# AWS Provider Upgrade Guide

This document explains the AWS provider upgrade required for CodeBuild compute fleet support and the fixes implemented.

## Problem

The original AWS provider version (`>= 3.0.0`) was too old to support CodeBuild compute fleets, which were introduced in AWS provider version 5.0.0. This caused several errors:

### 1. **Unsupported Block Type**
```
Error: Unsupported block type
  on modules/codebuild/main.tf line 19, in resource "aws_codebuild_project" "build":
  19:     dynamic "compute_fleet" {
Blocks of type "compute_fleet" are not expected here.
```

### 2. **Missing Required Argument**
```
Error: Missing required argument
  with module.compute_fleet.aws_codebuild_fleet.main,
  on modules/compute-fleet/main.tf line 6, in resource "aws_codebuild_fleet" "main":
   6: resource "aws_codebuild_fleet" "main" {
"vpc_config": all of `fleet_service_role,vpc_config` must be specified
```

### 3. **Invalid Resource Type**
```
Error: Invalid resource type
  on modules/compute-fleet/main.tf line 26, in resource "aws_codebuild_fleet_scaling_configuration" "main":
  26: resource "aws_codebuild_fleet_scaling_configuration" "main" {
The provider hashicorp/aws does not support resource type
"aws_codebuild_fleet_scaling_configuration".
```

## Solution

### 1. **Upgrade AWS Provider**

Updated the provider version constraint in `terraform/providers.tf`:

```hcl
# Before
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0.0" # Too old for compute fleets
    }
  }
}

# After
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0" # Required for CodeBuild compute fleets
    }
  }
}
```

### 2. **Fix CodeBuild Project Configuration**

The `compute_fleet` block should be at the resource level, not inside the environment block:

```hcl
# Before (Incorrect)
resource "aws_codebuild_project" "build" {
  environment {
    type = "LINUX_CONTAINER"
    compute_type = var.use_compute_fleet ? null : var.compute_type

    dynamic "compute_fleet" {  # ❌ Wrong location
      for_each = var.use_compute_fleet ? [1] : []
      content {
        fleet_arn = var.compute_fleet_arn
      }
    }
  }
}

# After (Correct)
resource "aws_codebuild_project" "build" {
  environment {
    type = "LINUX_CONTAINER"
    compute_type = var.use_compute_fleet ? null : var.compute_type
  }

  dynamic "compute_fleet" {  # ✅ Correct location
    for_each = var.use_compute_fleet ? [1] : []
    content {
      fleet_arn = var.compute_fleet_arn
    }
  }
}
```

### 3. **Add Required Fleet Service Role**

Added the required `fleet_service_role` to the compute fleet resource:

```hcl
# Before
resource "aws_codebuild_fleet" "main" {
  name = var.fleet_name
  base_capacity = var.base_capacity
  environment_type = var.environment_type
  compute_type = var.compute_type

  vpc_config {
    vpc_id             = var.vpc_id
    subnets            = var.private_subnet_ids
    security_group_ids = [var.security_group_id]
  }
}

# After
resource "aws_codebuild_fleet" "main" {
  name = var.fleet_name
  base_capacity = var.base_capacity
  environment_type = var.environment_type
  compute_type = var.compute_type
  fleet_service_role = aws_iam_role.fleet_role.arn  # ✅ Added required field

  vpc_config {
    vpc_id             = var.vpc_id
    subnets            = var.private_subnet_ids
    security_group_ids = [var.security_group_id]
  }
}
```

### 4. **Remove Unsupported Resource**

The `aws_codebuild_fleet_scaling_configuration` resource doesn't exist in the AWS provider. Removed it and implemented scaling through the Lambda function:

```hcl
# Before (Removed)
resource "aws_codebuild_fleet_scaling_configuration" "main" {
  fleet_name = aws_codebuild_fleet.main.name
  target_capacity = var.target_capacity
  max_capacity    = var.max_capacity
  min_capacity    = var.min_capacity
  scale_in_cooldown  = var.scale_in_cooldown
  scale_out_cooldown = var.scale_out_cooldown
}

# After (Handled by Lambda)
# Scaling configuration is managed through the Lambda function
# using the AWS SDK update_fleet_scaling_configuration API
```

### 5. **Add Fleet Initialization**

Added fleet initialization through the Lambda function:

```hcl
# Initialize fleet scaling configuration
resource "null_resource" "init_fleet" {
  depends_on = [module.fleet_controller]

  provisioner "local-exec" {
    command = "aws lambda invoke --function-name ${module.fleet_controller.function_name} --payload '{\"action\": \"init\"}' --region ${var.aws_region} /tmp/fleet_init_response.json"
  }
}
```

### 6. **Enhanced Lambda Function**

Added initialization capability to the Lambda function:

```python
def init_fleet(fleet_name, target_capacity):
    """Initialize the fleet with initial scaling configuration"""
    try:
        response = codebuild.update_fleet_scaling_configuration(
            fleetName=fleet_name,
            targetCapacity=target_capacity
        )

        logger.info(f"Initialized fleet {fleet_name} with target capacity: {target_capacity}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Fleet {fleet_name} initialized successfully',
                'target_capacity': target_capacity,
                'fleet_name': fleet_name
            })
        }
    except Exception as e:
        logger.error(f"Error initializing fleet: {str(e)}")
        raise
```

## Migration Steps

### 1. **Update Provider Version**

```bash
# Update the provider version in terraform/providers.tf
# Change version = ">= 3.0.0" to version = ">= 5.0.0"
```

### 2. **Initialize Terraform**

```bash
terraform init -upgrade
```

### 3. **Plan and Apply**

```bash
terraform plan
terraform apply
```

### 4. **Verify Deployment**

```bash
# Check if the fleet was created
aws codebuild describe-fleet --fleet-name codebuild-runners-fleet

# Check if Lambda function was created
aws lambda get-function --function-name codebuild-runners-fleet-controller
```

## Compatibility Notes

### **Breaking Changes**

1. **Provider Version**: Requires AWS provider >= 5.0.0
2. **Terraform Version**: Requires Terraform >= 1.6.6
3. **Resource Structure**: CodeBuild project structure changed

### **Backward Compatibility**

- Existing CodeBuild projects without compute fleets will continue to work
- The `use_compute_fleet` variable allows gradual migration
- Lambda function supports both old and new patterns

## Troubleshooting

### **Common Issues**

1. **Provider Version Conflicts**
   ```bash
   # Solution: Clear provider cache
   rm -rf .terraform
   terraform init -upgrade
   ```

2. **Permission Errors**
   ```bash
   # Solution: Ensure IAM roles have correct permissions
   aws iam get-role --role-name codebuild-runners-fleet-fleet-role
   ```

3. **Fleet Initialization Failures**
   ```bash
   # Solution: Manually initialize fleet
   ./scripts/fleet_control.sh init
   ```

### **Verification Commands**

```bash
# Check provider version
terraform version

# Check AWS provider version
terraform providers

# Verify fleet creation
aws codebuild list-fleets

# Test Lambda function
./scripts/fleet_control.sh status
```

## Best Practices

1. **Always Test**: Test provider upgrades in a non-production environment first
2. **Gradual Migration**: Use feature flags to gradually migrate to compute fleets
3. **Monitor Resources**: Monitor fleet utilization and costs after deployment
4. **Document Changes**: Keep documentation updated with provider requirements
5. **Backup State**: Backup Terraform state before major provider upgrades

This upgrade ensures compatibility with the latest AWS features while maintaining backward compatibility with existing infrastructure.
