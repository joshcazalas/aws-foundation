locals {
  budget_notifications = {
    actual-one-dollar = {
      notification_type = "ACTUAL"
      threshold         = 1
      threshold_type    = "ABSOLUTE_VALUE"
    }
    actual-fifty-percent = {
      notification_type = "ACTUAL"
      threshold         = 50
      threshold_type    = "PERCENTAGE"
    }
    actual-eighty-percent = {
      notification_type = "ACTUAL"
      threshold         = 80
      threshold_type    = "PERCENTAGE"
    }
    actual-one-hundred-percent = {
      notification_type = "ACTUAL"
      threshold         = 100
      threshold_type    = "PERCENTAGE"
    }
    forecast-one-hundred-percent = {
      notification_type = "FORECASTED"
      threshold         = 100
      threshold_type    = "PERCENTAGE"
    }
  }

  member_budgets = {
    for key, config in local.workload_accounts : key => {
      account_id  = aws_organizations_account.workload[key].id
      amount      = config.budget_amount
      environment = config.environment
      name        = "${config.name}-monthly-cost"
    }
  }
}

resource "aws_sns_topic" "budget_alerts" {
  name         = "aws-foundation-budget-alerts"
  display_name = "AWS budget alerts"

  tags = {
    ManagedBy  = "terraform"
    Project    = "aws-foundation"
    Repository = "joshcazalas/aws-foundation"
  }
}

data "aws_iam_policy_document" "budget_alerts" {
  statement {
    sid    = "AllowManagementAccountAdministration"
    effect = "Allow"

    actions   = ["sns:*"]
    resources = [aws_sns_topic.budget_alerts.arn]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.management_account_id}:root"]
    }
  }

  statement {
    sid    = "AllowAWSBudgetsPublish"
    effect = "Allow"

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.budget_alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.management_account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:budgets::${var.management_account_id}:*"]
    }
  }
}

resource "aws_sns_topic_policy" "budget_alerts" {
  arn    = aws_sns_topic.budget_alerts.arn
  policy = data.aws_iam_policy_document.budget_alerts.json
}

resource "aws_budgets_budget" "organization" {
  name         = "organization-monthly-cost"
  budget_type  = "COST"
  limit_amount = "25"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = local.budget_notifications

    content {
      comparison_operator       = "GREATER_THAN"
      notification_type         = notification.value.notification_type
      threshold                 = notification.value.threshold
      threshold_type            = notification.value.threshold_type
      subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
    }
  }

  tags = {
    ManagedBy  = "terraform"
    Project    = "aws-foundation"
    Repository = "joshcazalas/aws-foundation"
    Scope      = "organization"
  }

  depends_on = [aws_sns_topic_policy.budget_alerts]
}

resource "aws_budgets_budget" "member" {
  for_each = local.member_budgets

  name         = each.value.name
  budget_type  = "COST"
  limit_amount = tostring(each.value.amount)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "LinkedAccount"
    values = [each.value.account_id]
  }

  dynamic "notification" {
    for_each = local.budget_notifications

    content {
      comparison_operator       = "GREATER_THAN"
      notification_type         = notification.value.notification_type
      threshold                 = notification.value.threshold
      threshold_type            = notification.value.threshold_type
      subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
    }
  }

  tags = {
    Environment = each.value.environment
    ManagedBy   = "terraform"
    Project     = "money-on-record"
    Repository  = "joshcazalas/aws-foundation"
  }

  depends_on = [aws_sns_topic_policy.budget_alerts]
}
