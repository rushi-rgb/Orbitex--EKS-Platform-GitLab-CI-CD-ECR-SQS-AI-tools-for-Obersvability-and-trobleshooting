################################################################################
# Dev Environment — Root Terraform Configuration
# Orchestrates all modules to build the full EKS platform
################################################################################

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket         = "YOUR-TERRAFORM-STATE-BUCKET"
  #   key            = "eks-platform/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.env
    ManagedBy   = "Terraform"
    Team        = "Platform"
  }
  cluster_name = "${var.project}-${var.env}-cluster"
}

# ── VPC ───────────────────────────────────────────────────────────────────────
module "vpc" {
  source             = "../../modules/vpc"
  project            = var.project
  env                = var.env
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  cluster_name       = local.cluster_name
  tags               = local.common_tags
}

# ── EKS ───────────────────────────────────────────────────────────────────────
module "eks" {
  source               = "../../modules/eks"
  project              = var.project
  env                  = var.env
  cluster_name         = local.cluster_name
  kubernetes_version   = var.kubernetes_version
  vpc_id               = module.vpc.vpc_id
  public_subnet_ids    = module.vpc.public_subnet_ids
  private_subnet_ids   = module.vpc.private_subnet_ids
  node_instance_types  = var.node_instance_types
  node_desired         = var.node_desired
  node_min             = var.node_min
  node_max             = var.node_max
  tags                 = local.common_tags
}

# ── ECR ───────────────────────────────────────────────────────────────────────
module "ecr" {
  source  = "../../modules/ecr"
  project = var.project
  env     = var.env
  tags    = local.common_tags
}

# ── SQS ───────────────────────────────────────────────────────────────────────
module "sqs" {
  source  = "../../modules/sqs"
  project = var.project
  env     = var.env
  tags    = local.common_tags
}

# ── RDS — Content DB ──────────────────────────────────────────────────────────
module "rds_content" {
  source                    = "../../modules/rds"
  project                   = var.project
  env                       = var.env
  name                      = "content-db"
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]
  instance_class            = var.rds_instance_class
  db_password               = var.db_password_content
  tags                      = local.common_tags
}

# ── RDS — Auth DB ─────────────────────────────────────────────────────────────
module "rds_auth" {
  source                    = "../../modules/rds"
  project                   = var.project
  env                       = var.env
  name                      = "auth-db"
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]
  instance_class            = var.rds_instance_class
  db_password               = var.db_password_auth
  tags                      = local.common_tags
}

# ── RDS — Core DB ─────────────────────────────────────────────────────────────
module "rds_core" {
  source                    = "../../modules/rds"
  project                   = var.project
  env                       = var.env
  name                      = "core-db"
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]
  instance_class            = var.rds_instance_class
  db_password               = var.db_password_core
  tags                      = local.common_tags
}

# ── ElastiCache Redis ─────────────────────────────────────────────────────────
module "redis" {
  source                    = "../../modules/elasticache"
  project                   = var.project
  env                       = var.env
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]
  node_type                 = var.redis_node_type
  auth_token                = var.redis_auth_token
  tags                      = local.common_tags
}

# ── IAM / IRSA ────────────────────────────────────────────────────────────────
module "iam" {
  source              = "../../modules/iam"
  project             = var.project
  env                 = var.env
  aws_region          = var.aws_region
  cluster_name        = local.cluster_name
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url
  gitlab_project_path = var.gitlab_project_path
  sqs_queue_arns      = module.sqs.queue_arns
  tags                = local.common_tags
}

# ── Outputs for post-apply scripts ────────────────────────────────────────────
output "cluster_name"        { value = module.eks.cluster_name }
output "cluster_endpoint"    { value = module.eks.cluster_endpoint }
output "aws_region"          { value = var.aws_region }
output "ecr_urls"            { value = module.ecr.repository_urls }
output "sqs_queue_urls"      { value = module.sqs.queue_urls }
output "irsa_role_arns"      { value = module.iam.irsa_role_arns }
output "gitlab_ci_role_arn"  { value = module.iam.gitlab_ci_role_arn }
output "rds_content_endpoint"{ value = module.rds_content.endpoint }
output "rds_auth_endpoint"   { value = module.rds_auth.endpoint }
output "rds_core_endpoint"   { value = module.rds_core.endpoint }
output "redis_endpoint"      { value = module.redis.primary_endpoint }
