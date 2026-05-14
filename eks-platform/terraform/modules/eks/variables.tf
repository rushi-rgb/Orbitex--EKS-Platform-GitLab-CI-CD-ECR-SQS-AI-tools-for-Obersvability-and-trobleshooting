variable "project"                { type = string }
variable "env"                    { type = string }
variable "cluster_name"           { type = string }
variable "kubernetes_version"     { type = string; default = "1.29" }
variable "vpc_id"                 { type = string }
variable "public_subnet_ids"      { type = list(string) }
variable "private_subnet_ids"     { type = list(string) }
variable "node_instance_types"    { type = list(string); default = ["t3.medium"] }
variable "node_desired"           { type = number; default = 2 }
variable "node_min"               { type = number; default = 2 }
variable "node_max"               { type = number; default = 10 }
variable "capacity_type"          { type = string; default = "ON_DEMAND" }
variable "endpoint_public_access" { type = bool; default = true }
variable "tags"                   { type = map(string); default = {} }
