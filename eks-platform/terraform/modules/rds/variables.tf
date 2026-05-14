variable "project"                    { type = string }
variable "env"                        { type = string }
variable "name"                       { type = string }
variable "vpc_id"                     { type = string }
variable "subnet_ids"                 { type = list(string) }
variable "allowed_security_group_ids" { type = list(string) }
variable "instance_class"             { type = string; default = "db.t3.medium" }
variable "allocated_storage"          { type = number; default = 20 }
variable "multi_az"                   { type = bool; default = false }
variable "db_username"                { type = string; default = "dbadmin" }
variable "db_password"                { type = string; sensitive = true }
variable "tags"                       { type = map(string); default = {} }
