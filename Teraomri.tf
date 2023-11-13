# Configure the AWS provider
provider "aws" {
  region = "us-east-1"
}

# Create a Lambda role with CloudWatch logs policy
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs_policy" {
  role = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create a Lambda function with the Python code
resource "aws_lambda_function" "github_webhook" {
  function_name = "github_webhook"
  role = aws_iam_role.lambda_role.arn
  handler = "lambda_function.lambda_handler"
  runtime = "python3.8"
  # Zip the Python code and upload it to Lambda
  filename = "${path.module}/lambda_function.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_function.zip")
}

# Create an API Gateway endpoint that will invoke the Lambda function
resource "aws_api_gateway_rest_api" "github_api" {
  name = "github_api"
  description = "API Gateway for GitHub webhook"
}

resource "aws_api_gateway_resource" "github_resource" {
  rest_api_id = aws_api_gateway_rest_api.github_api.id
  parent_id = aws_api_gateway_rest_api.github_api.root_resource_id
  path_part = "{proxy+}"
}

resource "aws_api_gateway_method" "github_method" {
  rest_api_id = aws_api_gateway_rest_api.github_api.id
  resource_id = aws_api_gateway_resource.github_resource.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "github_integration" {
  rest_api_id = aws_api_gateway_rest_api.github_api.id
  resource_id = aws_api_gateway_resource.github_resource.id
  http_method = aws_api_gateway_method.github_method.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.github_webhook.invoke_arn
}

resource "aws_api_gateway_deployment" "github_deployment" {
  depends_on = [
    aws_api_gateway_integration.github_integration,
  ]
  rest_api_id  = aws_api_gateway_rest_api.github_api.id
  stage_name = "prod"
}

# Create a GitHub provider with your GitHub token
provider "github" {
  token = "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" # GitHub token
}

# Create a GitHub repository webhook to trigger the API Gateway endpoint
resource "github_repository_webhook" "github_webhook" {
  repository = "7757574874" # Repository name
  configuration {
    url = aws_api_gateway_deployment.github_deployment.invoke_url # The API Gateway endpoint URL
    content_type = "json"
    insecure_ssl = false
  }

  events = ["pull_request"]
}
