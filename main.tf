locals {
  fqdn = length(var.hostname) > 0 ? "${var.hostname}.${var.domain}" : "${var.domain}"
}

resource "aws_api_gateway_domain_name" "default" {
  domain_name              = local.fqdn
  regional_certificate_arn = module.acm.arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_base_path_mapping" "default" {
  api_id      = aws_api_gateway_rest_api.default.id
  stage_name  = aws_api_gateway_deployment.default.stage_name
  domain_name = aws_api_gateway_domain_name.default.domain_name
}

module "acm" {
  source = "./acm"

  hostname      = var.hostname
  domain        = var.domain
  target_domain = aws_api_gateway_domain_name.default.regional_domain_name
  zone_id       = aws_api_gateway_domain_name.default.regional_zone_id
}

resource "aws_iam_role" "default-role" {
  name = "directory-editor-dev"

  assume_role_policy = "{\"Version\": \"2012-10-17\", \"Statement\": [{\"Sid\": \"\", \"Effect\": \"Allow\", \"Principal\": {\"Service\": \"lambda.amazonaws.com\"}, \"Action\": \"sts:AssumeRole\"}]}"
}

resource "aws_iam_role_policy" "default-role" {
  name = "default-rolePolicy"

  policy = "{\"Version\": \"2012-10-17\", \"Statement\": [{\"Effect\": \"Allow\", \"Action\": [\"ssm:GetParameter\"], \"Resource\": [\"*\"], \"Sid\": \"df6d872f50e842deb1f26f915aea818e\"}, {\"Effect\": \"Allow\", \"Action\": [\"logs:CreateLogGroup\", \"logs:CreateLogStream\", \"logs:PutLogEvents\"], \"Resource\": \"arn:aws:logs:*:*:*\"}]}"

  role = aws_iam_role.default-role.id
}

resource "aws_lambda_function" "default" {
  function_name = "directory-editor-dev"

  runtime = "python3.6"

  handler = "app.app"

  memory_size = 128

  tags = {
    aws-chalice = "version=1.12.0:stage=dev:app=directory-editor"
  }

  timeout = 60

  source_code_hash = filebase64sha256("./deployment.zip")

  filename = "./deployment.zip"

  environment {
    variables = {
      STAGE = "dev"
    }
  }

  role = aws_iam_role.default-role.arn
}


resource "aws_api_gateway_rest_api" "default" {
  name = "directory-editor-api"

  # endpoint_configuration {
  #   types = ["EDGE"]
  # }
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  parent_id   = aws_api_gateway_rest_api.default.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.default.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.default.invoke_arn
}

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.default.id
  resource_id   = aws_api_gateway_rest_api.default.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  resource_id = aws_api_gateway_method.proxy_root.resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.default.invoke_arn
}

resource "aws_api_gateway_deployment" "default" {
  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration.lambda_root,
  ]

  rest_api_id = aws_api_gateway_rest_api.default.id
  stage_name  = "v1"
}

resource "aws_lambda_permission" "rest_api_invoke" {
  function_name = "directory-editor-dev"

  action = "lambda:InvokeFunction"

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.default.execution_arn}/*"
}

terraform {
  required_version = "> 0.11.0, < 0.13.0"
}

provider "template" {
  version = "~> 2"
}

provider "null" {
  version = "~> 2"
}

data "aws_caller_identity" "chalice" {}

data "aws_region" "chalice" {}

#data "null_data_source" "chalice" "inputs" {
#  app = "directory-editor"
#
#  stage = "dev"
#}
