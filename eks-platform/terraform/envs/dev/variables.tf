variable "project"             { type = string }
variable "env"                 { type = string }
variable "aws_region"          { type = string }
variable "vpc_cidr"            { type = string }
variable "availability_zones"  { type = list(string) }
variable "kubernetes_version"  { type = string }
variable "node_instance_types" { type = list(string) }
variable "node_desired"        { type = number }
variable "node_min"            { type = number }
variable "node_max"            { type = number }
variable "rds_instance_class"  { type = string }
variable "redis_node_type"     { type = string }
variable "gitlab_project_path" { type = string }
variable "db_password_content" { type = string; sensitive = true }
variable "db_password_auth"    { type = string; sensitive = true }
variable "db_password_core"    { type = string; sensitive = true }
variable "redis_auth_token"    { type = string; sensitive = true }
