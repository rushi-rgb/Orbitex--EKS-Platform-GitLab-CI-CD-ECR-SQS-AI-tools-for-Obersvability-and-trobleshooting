project            = "eks-platform"
env                = "prod"
aws_region         = "us-east-1"
vpc_cidr           = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
kubernetes_version = "1.29"

node_instance_types = ["m5.xlarge"]
node_desired        = 3
node_min            = 3
node_max            = 20

rds_instance_class = "db.r6g.large"
redis_node_type    = "cache.r6g.large"

gitlab_project_path = "YOUR_GITLAB_GROUP/YOUR_GITLAB_PROJECT"
