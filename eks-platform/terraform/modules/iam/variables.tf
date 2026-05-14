variable "project"             { type = string }
variable "env"                 { type = string }
variable "aws_region"          { type = string }
variable "cluster_name"        { type = string }
variable "oidc_provider_arn"   { type = string }
variable "oidc_provider_url"   { type = string }
variable "gitlab_project_path" { type = string }
variable "sqs_queue_arns"      { type = map(string) }
variable "tags"                { type = map(string); default = {} }
