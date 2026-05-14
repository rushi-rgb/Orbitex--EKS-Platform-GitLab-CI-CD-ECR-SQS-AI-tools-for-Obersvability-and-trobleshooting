################################################################################
# SQS Module — 4 Async Job Queues
# content-jobs-queue, market-data-queue, ai-jobs-queue, notification-queue
################################################################################

locals {
  queues = [
    "content-jobs",
    "market-data",
    "ai-jobs",
    "notification",
  ]
}

resource "aws_sqs_queue" "dlq" {
  for_each                   = toset(local.queues)
  name                       = "${var.project}-${var.env}-${each.key}-dlq"
  message_retention_seconds  = 1209600 # 14 days
  kms_master_key_id          = "alias/aws/sqs"
  tags                       = merge(var.tags, { Name = "${var.project}-${var.env}-${each.key}-dlq" })
}

resource "aws_sqs_queue" "main" {
  for_each                   = toset(local.queues)
  name                       = "${var.project}-${var.env}-${each.key}-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400 # 1 day
  receive_wait_time_seconds  = 20    # Long polling
  kms_master_key_id          = "alias/aws/sqs"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = 3
  })

  tags = merge(var.tags, { Name = "${var.project}-${var.env}-${each.key}-queue" })
}

output "queue_urls" {
  value = { for k, q in aws_sqs_queue.main : k => q.url }
}

output "queue_arns" {
  value = { for k, q in aws_sqs_queue.main : k => q.arn }
}

output "dlq_arns" {
  value = { for k, q in aws_sqs_queue.dlq : k => q.arn }
}
