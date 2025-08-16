# Generic Lambda Function Module
# This module creates a Lambda function with proper packaging and deployment

# Build Lambda function with dependencies
resource "null_resource" "build_lambda" {
  count = var.build_package ? 1 : 0

  triggers = {
    source_code_hash = filemd5("${path.module}/src/${var.function_directory != null ? "${var.function_directory}/" : ""}${var.handler_file}")
    requirements_hash = fileexists("${path.module}/src/${var.function_directory != null ? "${var.function_directory}/" : ""}requirements.txt") ? filemd5("${path.module}/src/${var.function_directory != null ? "${var.function_directory}/" : ""}requirements.txt") : "no-requirements"
    build_script_hash = filemd5("${path.module}/build.sh")
  }

  provisioner "local-exec" {
    command = "${path.module}/build.sh --clean --validate"
    environment = {
      FUNCTION_NAME = var.function_name
      FUNCTION_DIRECTORY = var.function_directory
    }
  }
}

# Lambda function
resource "aws_lambda_function" "main" {
  filename         = var.build_package ? "${path.module}/dist/${var.function_name}.zip" : var.source_file
  function_name    = var.function_name
  role            = var.role_arn
  handler         = var.handler
  runtime         = var.runtime
  timeout         = var.timeout
  memory_size     = var.memory_size
  description     = var.description
  source_code_hash = var.build_package ? data.archive_file.lambda_zip[0].output_base64sha256 : null

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = var.tags

  depends_on = [null_resource.build_lambda]
}

# Reference the existing Lambda package for hash calculation
data "archive_file" "lambda_zip" {
  count = var.build_package ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/dist/${var.function_name}.zip"
  output_path = "${path.module}/dist/${var.function_name}.zip"
  depends_on  = [null_resource.build_lambda]
}



# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# IAM Role for Lambda (if not provided)
resource "aws_iam_role" "lambda_role" {
  count = var.create_role ? 1 : 0

  name = "${var.function_name}-role"

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

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  count = var.create_role ? 1 : 0

  role       = aws_iam_role.lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC execution policy (if VPC config is provided)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count = var.create_role && var.vpc_config != null ? 1 : 0

  role       = aws_iam_role.lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom IAM policies
resource "aws_iam_role_policy" "lambda_custom" {
  for_each = var.create_role ? var.custom_policies : {}

  name = "${var.function_name}-${each.key}"
  role = aws_iam_role.lambda_role[0].id

  policy = each.value
}

# EventBridge rule (optional)
resource "aws_cloudwatch_event_rule" "lambda_trigger" {
  count = var.event_rule != null ? 1 : 0

  name                = "${var.function_name}-trigger"
  description         = var.event_rule.description
  schedule_expression = var.event_rule.schedule_expression
  event_pattern       = var.event_rule.event_pattern

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  count = var.event_rule != null ? 1 : 0

  rule      = aws_cloudwatch_event_rule.lambda_trigger[0].name
  target_id = "LambdaTarget"
  arn       = aws_lambda_function.main.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count = var.event_rule != null ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_trigger[0].arn
}
