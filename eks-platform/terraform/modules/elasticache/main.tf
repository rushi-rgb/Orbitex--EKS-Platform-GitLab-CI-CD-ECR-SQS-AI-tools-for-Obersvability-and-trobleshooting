################################################################################
# ElastiCache Redis — Auth service session store
################################################################################

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-${var.env}-redis-subnet"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "redis" {
  name        = "${var.project}-${var.env}-redis-sg"
  description = "Redis ElastiCache security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "Redis from EKS auth pods"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project}-${var.env}-redis-sg" })
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project}-${var.env}-redis"
  description          = "Redis cluster for ${var.project} ${var.env}"

  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.node_type
  num_cache_clusters   = var.env == "prod" ? 2 : 1
  port                 = 6379

  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.auth_token

  automatic_failover_enabled = var.env == "prod"
  multi_az_enabled           = var.env == "prod"

  snapshot_retention_limit = var.env == "prod" ? 3 : 0

  tags = merge(var.tags, { Name = "${var.project}-${var.env}-redis" })
}

output "primary_endpoint" { value = aws_elasticache_replication_group.main.primary_endpoint_address }
output "port"             { value = 6379 }
output "sg_id"            { value = aws_security_group.redis.id }
