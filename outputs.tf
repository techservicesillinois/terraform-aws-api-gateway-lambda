# TODO: put code here or delete this file!
output "bar" {
  value = "foo"
}

output "endpoint_url" {
  value = aws_api_gateway_deployment.default.invoke_url
}
