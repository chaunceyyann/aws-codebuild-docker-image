# CodeBuild Compute Fleet Setup and Management

This document describes how to set up and manage AWS CodeBuild compute fleets for pre-warmed EC2 instances to improve build performance and reduce costs.

## Overview

The CodeBuild compute fleet provides pre-warmed EC2 instances that can significantly reduce build start times. This implementation includes:

- **Pre-warmed instances**: Reduces build start time from minutes to seconds
- **Manual control**: Start/stop fleet to optimize costs
- **Auto-scaling**: Automatically scales based on demand
- **Monitoring**: Real-time metrics and dashboard
- **Cost optimization**: Manual control to turn off during non-business hours

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub Repo   │───▶│  CodeBuild Fleet │───▶│  Pre-warmed     │
│                 │    │                  │    │  EC2 Instances  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │ Lambda Controller│
                       │ (Manual Control) │
                       └──────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │ CloudWatch       │
                       │ (Monitoring)     │
                       └──────────────────┘
```

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed (version >= 1.0)
- Existing VPC and security groups
- CodeBuild service role with necessary permissions

## Deployment

### 1. Configure Variables

Update the `terraform/variables.tf` file or create a `terraform.tfvars` file:

```hcl
# Compute Fleet Configuration
fleet_base_capacity    = 1
fleet_target_capacity  = 2
fleet_max_capacity     = 10
fleet_min_capacity     = 0
enable_fleet_for_runners = true

# Optional: Enable scheduled control
enable_scheduled_control = false
schedule_expression     = "cron(0 8 * * ? *)"  # 8 AM UTC daily
```

### 2. Lambda Function Packaging

The compute fleet module uses the generic Lambda module for the fleet controller function. The Lambda function is automatically packaged with dependencies during deployment.

The Lambda function code is located in `terraform/modules/lambda/src/fleet_controller.py` and uses the following configuration:

```hcl
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

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### 4. Verify Deployment

```bash
# Check if the fleet was created
aws codebuild describe-fleet --fleet-name codebuild-runners-fleet

# Check if Lambda function was created
aws lambda get-function --function-name codebuild-runners-fleet-controller
```

## Fleet Management

### Manual Control Script

Use the provided script to manually control the fleet:

```bash
# Start the fleet with default capacity (2)
./scripts/fleet_control.sh start

# Start the fleet with custom capacity
./scripts/fleet_control.sh start 5

# Stop the fleet (set capacity to 0)
./scripts/fleet_control.sh stop

# Check fleet status
./scripts/fleet_control.sh status

# Monitor fleet metrics in real-time
./scripts/fleet_control.sh monitor
```

### AWS CLI Commands

You can also use AWS CLI directly:

```bash
# Start fleet
aws lambda invoke \
  --function-name codebuild-runners-fleet-controller \
  --payload '{"action": "start", "target_capacity": 2}' \
  response.json

# Stop fleet
aws lambda invoke \
  --function-name codebuild-runners-fleet-controller \
  --payload '{"action": "stop"}' \
  response.json

# Get status
aws lambda invoke \
  --function-name codebuild-runners-fleet-controller \
  --payload '{"action": "status"}' \
  response.json
```

### Scheduled Control

To enable automatic fleet control based on schedule:

1. Set `enable_scheduled_control = true` in your Terraform variables
2. Configure the `schedule_expression` (cron format)
3. Deploy the changes

Example schedules:
- `cron(0 8 * * ? *)` - Start at 8 AM UTC daily
- `cron(0 18 * * ? *)` - Stop at 6 PM UTC daily
- `cron(0 8 ? * MON-FRI *)` - Start at 8 AM UTC on weekdays only

## Monitoring

### CloudWatch Dashboard

A CloudWatch dashboard is automatically created with the name `codebuild-runners-fleet-dashboard`. It includes:

- Fleet capacity metrics
- Fleet utilization metrics
- Build status overview

### Key Metrics

- **FleetCapacity**: Current number of instances in the fleet
- **FleetUtilization**: Percentage of fleet capacity being used
- **BuildDuration**: Time taken for builds to complete
- **BuildSuccessRate**: Percentage of successful builds

### Alarms

Consider setting up CloudWatch alarms for:

- High fleet utilization (>80%)
- Low fleet utilization (<20%)
- Build failure rate (>10%)
- Fleet scaling events

## Cost Optimization

### Best Practices

1. **Manual Control**: Use the control script to start/stop fleet during business hours
2. **Scheduled Control**: Enable automatic scheduling for predictable usage patterns
3. **Right-sizing**: Monitor utilization and adjust capacity accordingly
4. **Idle Timeout**: Set appropriate cooldown periods to avoid unnecessary scaling

### Cost Estimation

Example cost calculation for `BUILD_GENERAL1_MEDIUM` instances:

- **Per instance per hour**: ~$0.05
- **Daily cost (2 instances, 8 hours)**: ~$0.80
- **Monthly cost**: ~$24

Compare this to standard CodeBuild pricing and your specific usage patterns.

## Troubleshooting

### Common Issues

1. **Fleet not starting**
   - Check IAM permissions for the Lambda function
   - Verify the fleet name matches the configuration
   - Check CloudWatch logs for Lambda errors

2. **Builds not using fleet**
   - Ensure `use_compute_fleet = true` in CodeBuild project configuration
   - Verify the fleet ARN is correctly set
   - Check that the fleet has available capacity

3. **High costs**
   - Monitor fleet utilization
   - Use the stop command when not needed
   - Consider reducing target capacity

### Debugging Commands

```bash
# Check Lambda function logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/codebuild-runners-fleet-controller"

# Check fleet scaling configuration
aws codebuild describe-fleet-scaling-configuration --fleet-name codebuild-runners-fleet

# List recent builds
aws codebuild list-builds --max-items 10

# Check build details
aws codebuild batch-get-builds --ids <build-id>
```

## Security Considerations

1. **IAM Permissions**: Ensure minimal required permissions for the Lambda function
2. **VPC Configuration**: Fleet instances run in private subnets with restricted access
3. **Security Groups**: Configure appropriate security group rules
4. **Encryption**: All data in transit and at rest is encrypted

## Migration from Standard CodeBuild

To migrate existing CodeBuild projects to use the fleet:

1. Update the project configuration to include fleet parameters
2. Test with a single project first
3. Gradually migrate other projects
4. Monitor performance and costs

## Support

For issues or questions:

1. Check CloudWatch logs for detailed error messages
2. Review the troubleshooting section above
3. Consult AWS CodeBuild documentation
4. Check the project's GitHub issues

## References

- [AWS CodeBuild Compute Fleets](https://docs.aws.amazon.com/codebuild/latest/userguide/compute-fleets.html)
- [AWS CodeBuild Pricing](https://aws.amazon.com/codebuild/pricing/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
