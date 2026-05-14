################################################################################
# RDS Module — PostgreSQL instances per service group
################################################################################

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.env}-${var.name}-db-subnet"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.project}-${var.env}-${var.name}-db-subnet" })
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.env}-${var.name}-rds-sg"
  description = "RDS security group for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "PostgreSQL from EKS pods"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project}-${var.env}-${var.name}-rds-sg" })
}

resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "${var.project}-${var.env}-${var.name}-pg15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # log slow queries > 1s
  }

  tags = var.tags
}

resource "aws_db_instance" "main" {
  identifier        = "${var.project}-${var.env}-${var.name}"
  engine            = "postgres"
  engine_version    = "15.4"
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = replace(var.name, "-", "_")
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  multi_az               = var.multi_az
  publicly_accessible    = false
  skip_final_snapshot    = var.env == "dev"
  deletion_protection    = var.env == "prod"
  backup_retention_period = var.env == "prod" ? 7 : 1
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  performance_insights_enabled = true

  tags = merge(var.tags, { Name = "${var.project}-${var.env}-${var.name}" })
}

output "endpoint"    { value = aws_db_instance.main.endpoint }
output "db_name"     { value = aws_db_instance.main.db_name }
output "port"        { value = aws_db_instance.main.port }
output "sg_id"       { value = aws_security_group.rds.id }
