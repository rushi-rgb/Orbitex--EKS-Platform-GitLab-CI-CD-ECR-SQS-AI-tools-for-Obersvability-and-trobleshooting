################################################################################
# IAM Module — IRSA roles per service + GitLab OIDC federation
################################################################################

locals {
  account_id = data.aws_caller_identity.current.account_id
  oidc_url   = replace(var.oidc_provider_url, "https://", "")
}

data "aws_caller_identity" "current" {}

# ── GitLab OIDC Provider ──────────────────────────────────────────────────────
resource "aws_iam_openid_connect_provider" "gitlab" {
  url             = "https://gitlab.com"
  client_id_list  = ["https://gitlab.com"]
  thumbprint_list = ["b3dd7606d2b5a8b4a13771dbecc9ee1cecafa38a"]
  tags            = var.tags
}

# ── GitLab CI/CD Role (OIDC, no static keys) ─────────────────────────────────
data "aws_iam_policy_document" "gitlab_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.gitlab.arn]
    }
    condition {
      test     = "StringLike"
      variable = "gitlab.com:sub"
      values   = ["project_path:${var.gitlab_project_path}:ref_type:branch:ref:*"]
    }
  }
}

resource "aws_iam_role" "gitlab_ci" {
  name               = "${var.project}-${var.env}-gitlab-ci-role"
  assume_role_policy = data.aws_iam_policy_document.gitlab_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "gitlab_ci" {
  name = "ecr-and-eks"
  role = aws_iam_role.gitlab_ci.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${var.project}/${var.env}/*"
      },
      {
        Sid    = "EKSDeploy"
        Effect = "Allow"
        Action = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:${var.aws_region}:${local.account_id}:cluster/${var.cluster_name}"
      },
    ]
  })
}

# ── IRSA Helper ───────────────────────────────────────────────────────────────
locals {
  irsa_roles = {
    "content-service" = {
      namespace       = "platform"
      service_account = "content-service-sa"
      actions = [
        "s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket",
        "sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage",
      ]
      resources = [
        "arn:aws:s3:::${var.project}-${var.env}-content/*",
        var.sqs_queue_arns["content-jobs"],
      ]
    }
    "auth-service" = {
      namespace       = "platform"
      service_account = "auth-service-sa"
      actions = [
        "secretsmanager:GetSecretValue",
        "kms:Decrypt",
      ]
      resources = ["arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${var.project}/${var.env}/auth/*"]
    }
    "ai-service" = {
      namespace       = "platform"
      service_account = "ai-service-sa"
      actions = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "sqs:SendMessage",
      ]
      resources = [
        "arn:aws:bedrock:${var.aws_region}::foundation-model/*",
        var.sqs_queue_arns["ai-jobs"],
      ]
    }
    "background-worker" = {
      namespace       = "platform"
      service_account = "background-worker-sa"
      actions = [
        "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes",
        "ses:SendEmail", "ses:SendRawEmail",
        "s3:PutObject", "s3:GetObject",
      ]
      resources = concat(values(var.sqs_queue_arns), [
        "arn:aws:s3:::${var.project}-${var.env}-content/*",
      ])
    }
  }
}

data "aws_iam_policy_document" "irsa_assume" {
  for_each = local.irsa_roles
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each           = local.irsa_roles
  name               = "${var.project}-${var.env}-${each.key}-irsa"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume[each.key].json
  tags               = var.tags
}

resource "aws_iam_role_policy" "irsa" {
  for_each = local.irsa_roles
  name     = "permissions"
  role     = aws_iam_role.irsa[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = each.value.actions
      Resource = each.value.resources
    }]
  })
}

output "irsa_role_arns" {
  value = { for k, r in aws_iam_role.irsa : k => r.arn }
}

output "gitlab_ci_role_arn" {
  value = aws_iam_role.gitlab_ci.arn
}
