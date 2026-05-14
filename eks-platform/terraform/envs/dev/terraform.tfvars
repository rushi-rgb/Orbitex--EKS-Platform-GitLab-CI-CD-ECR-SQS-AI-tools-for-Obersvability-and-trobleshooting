project            = "eks-platform"
env                = "dev"
aws_region         = "us-east-1"
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
kubernetes_version = "1.29"

# Node groups
node_instance_types = ["t3.medium"]
node_desired        = 2
node_min            = 2
node_max            = 6

# RDS
rds_instance_class = "db.t3.medium"

# Redis
redis_node_type = "cache.t3.micro"

# GitLab
gitlab_project_path = "YOUR_GITLAB_GROUP/YOUR_GITLAB_PROJECT"

# Secrets — use AWS Secrets Manager or CI/CD env vars in production
# db_password_content = set via TF_VAR_db_password_content env var
# db_password_auth    = set via TF_VAR_db_password_auth env var
# db_password_core    = set via TF_VAR_db_password_core env var
# redis_auth_token    = set via TF_VAR_redis_auth_token env var
