# Preserve the state identities created by the original Money on Record account
# model while adopting generic shared workload accounts. These moves change only
# OpenTofu addresses; the underlying AWS accounts and resources stay in place.

moved {
  from = aws_organizations_account.workload["money-on-record-prod"]
  to   = aws_organizations_account.foundation["workloads-prod"]
}

moved {
  from = aws_organizations_account.workload["money-on-record-uat"]
  to   = aws_organizations_account.foundation["workloads-uat"]
}

moved {
  from = aws_organizations_policy_attachment.full_aws_access["money-on-record-prod"]
  to   = aws_organizations_policy_attachment.full_aws_access["workloads-prod"]
}

moved {
  from = aws_organizations_policy_attachment.full_aws_access["money-on-record-uat"]
  to   = aws_organizations_policy_attachment.full_aws_access["workloads-uat"]
}

moved {
  from = aws_ssoadmin_account_assignment.this["money-on-record-prod:bootstrap-administrator"]
  to   = aws_ssoadmin_account_assignment.this["workloads-prod:bootstrap-administrator"]
}

moved {
  from = aws_ssoadmin_account_assignment.this["money-on-record-prod:read-only"]
  to   = aws_ssoadmin_account_assignment.this["workloads-prod:read-only"]
}

moved {
  from = aws_ssoadmin_account_assignment.this["money-on-record-uat:bootstrap-administrator"]
  to   = aws_ssoadmin_account_assignment.this["workloads-uat:bootstrap-administrator"]
}

moved {
  from = aws_ssoadmin_account_assignment.this["money-on-record-uat:read-only"]
  to   = aws_ssoadmin_account_assignment.this["workloads-uat:read-only"]
}

moved {
  from = aws_budgets_budget.member["money-on-record-prod"]
  to   = aws_budgets_budget.account["workloads-prod"]
}

moved {
  from = aws_budgets_budget.member["money-on-record-uat"]
  to   = aws_budgets_budget.account["workloads-uat"]
}
