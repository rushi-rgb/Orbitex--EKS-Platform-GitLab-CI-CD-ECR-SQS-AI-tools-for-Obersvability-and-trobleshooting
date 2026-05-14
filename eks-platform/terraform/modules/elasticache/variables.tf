variable "project"                    { type = string }
variable "env"                        { type = string }
variable "vpc_id"                     { type = string }
variable "subnet_ids"                 { type = list(string) }
variable "allowed_security_group_ids" { type = list(string) }
variable "node_type"                  { type = string; default = "cache.t3.micro" }
variable "auth_token"                 { type = string; sensitive = true }
variable "tags"                       { type = map(string); default = {} }
