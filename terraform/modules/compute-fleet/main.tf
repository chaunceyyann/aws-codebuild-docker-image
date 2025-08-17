# AWS CodeBuild Compute Fleet Module
# This module creates a compute fleet for CodeBuild with pre-warmed EC2 instances
# and manual control capabilities for cost optimization

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Compute Fleet
resource "aws_codebuild_fleet" "main" {
  name = var.fleet_name

  base_capacity = var.base_capacity
  environment_type = var.environment_type
  compute_type = var.compute_type
  fleet_service_role = aws_iam_role.fleet_role.arn

  vpc_config {
    vpc_id             = var.vpc_id
    subnets            = [var.private_subnet_ids[0]]  # CodeBuild fleets only support 1 subnet
    security_group_ids = [var.security_group_id]
  }

  tags = merge(var.tags, {
    Name = var.fleet_name
    Project = "codebuild-compute-fleet"
  })
}

# Initialize fleet scaling configuration
resource "null_resource" "init_fleet" {
  depends_on = [module.fleet_controller]

  provisioner "local-exec" {
    command = "aws lambda invoke --function-name ${module.fleet_controller.function_name} --payload '{\"action\": \"init\"}' --cli-binary-format raw-in-base64-out --region ${var.aws_region} /tmp/fleet_init_response.json"
  }
}



# IAM Role for the compute fleet
resource "aws_iam_role" "fleet_role" {
  name = "${var.fleet_name}-fleet-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for the compute fleet
resource "aws_iam_role_policy" "fleet_policy" {
  name = "${var.fleet_name}-fleet-policy"
  role = aws_iam_role.fleet_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = var.artifacts_bucket_arn == "*" ? "*" : "${var.artifacts_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "codeartifact:GetAuthorizationToken",
          "codeartifact:GetRepositoryEndpoint",
          "codeartifact:ReadFromRepository"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaceAttribute",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:DescribeDhcpOptions",
          "ec2:CreateNetworkInterfacePermission"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda function to control fleet scaling (manual on/off)
module "fleet_controller" {
  source = "../lambda"

  function_name = "${var.fleet_name}-controller"
  function_directory = "fleet-controller"
  handler_file  = "main.py"
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  timeout       = 300
  description   = "Lambda function to control CodeBuild fleet scaling"

  environment_variables = {
    FLEET_NAME = aws_codebuild_fleet.main.name
    FLEET_ARN  = aws_codebuild_fleet.main.arn
    TARGET_CAPACITY_ON  = var.target_capacity
    TARGET_CAPACITY_OFF = 1
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
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "codebuild:UpdateFleet",
            "codebuild:BatchGetFleets"
          ]
          Resource = "arn:aws:codebuild:${var.aws_region}:${data.aws_caller_identity.current.account_id}:fleet/${var.fleet_name}:*"
        },
        {
          Effect = "Allow"
          Action = [
            "codebuild:ListProjects"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "codebuild:BatchGetProjects",
            "codebuild:UpdateProject"
          ]
          Resource = "arn:aws:codebuild:${var.aws_region}:${data.aws_caller_identity.current.account_id}:project/*"
        },
        {
          Effect = "Allow"
          Action = [
            "events:EnableRule",
            "events:DisableRule",
            "events:DescribeRule"
          ]
          Resource = "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/${var.fleet_name}-schedule"
        }
      ]
    })
  }

  tags = var.tags
}

# IAM Role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "${var.fleet_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}





# EventBridge rule for scheduled fleet control (optional)
resource "aws_cloudwatch_event_rule" "fleet_schedule" {
  count = var.enable_scheduled_control ? 1 : 0

  name                = "${var.fleet_name}-schedule"
  description         = "Schedule for fleet scaling control"
  schedule_expression = var.schedule_expression

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "fleet_schedule_target" {
  count = var.enable_scheduled_control ? 1 : 0

  rule      = aws_cloudwatch_event_rule.fleet_schedule[0].name
  target_id = "FleetControllerTarget"
  arn       = module.fleet_controller.function_arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count = var.enable_scheduled_control ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.fleet_controller.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.fleet_schedule[0].arn
}

# CloudWatch dashboard for fleet monitoring
resource "aws_cloudwatch_dashboard" "fleet_dashboard" {
  dashboard_name = "${var.fleet_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/CodeBuild", "FleetCapacity", "FleetName", aws_codebuild_fleet.main.name],
            [".", "FleetUtilization", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Fleet Capacity and Utilization"
        }
      }
    ]
  })
}
