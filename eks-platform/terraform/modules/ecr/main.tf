################################################################################
# ECR Module — Container registries per microservice
################################################################################

locals {
  services = [
    "api-router",
    "content-service",
    "auth-service",
    "core-service",
    "ai-service",
    "background-worker",
  ]
}

resource "aws_ecr_repository" "services" {
  for_each             = toset(local.services)
  name                 = "${var.project}/${var.env}/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, { Name = "${var.project}-${var.env}-${each.key}" })
}

resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}

output "repository_urls" {
  value = { for k, r in aws_ecr_repository.services : k => r.repository_url }
}
