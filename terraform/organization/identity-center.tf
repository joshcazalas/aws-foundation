locals {
  permission_sets = {
    bootstrap-administrator = {
      name               = "BootstrapAdministrator"
      session_duration   = "PT1H"
      managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    }
    read-only = {
      name               = "ReadOnly"
      session_duration   = "PT4H"
      managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
    }
  }

  identity_center_account_targets = merge(
    { management = var.management_account_id },
    { for key, account in aws_organizations_account.foundation : key => account.id },
  )

  identity_center_assignment_pairs = {
    for pair in setproduct(keys(local.identity_center_account_targets), keys(local.permission_sets)) :
    "${pair[0]}:${pair[1]}" => {
      account_key        = pair[0]
      permission_set_key = pair[1]
    }
  }
}

resource "aws_ssoadmin_permission_set" "this" {
  for_each = local.permission_sets

  instance_arn     = var.identity_center_instance_arn
  name             = each.value.name
  session_duration = each.value.session_duration

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = local.identity_center_assignment_pairs

  instance_arn       = var.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set_key].arn

  principal_id   = var.identity_center_principal_id
  principal_type = "USER"

  target_id   = local.identity_center_account_targets[each.value.account_key]
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = local.permission_sets

  instance_arn       = var.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  managed_policy_arn = each.value.managed_policy_arn

  # AWS re-provisions every account assignment when an attached policy changes.
  # This dependency also preserves the provider-recommended deletion order.
  depends_on = [aws_ssoadmin_account_assignment.this]
}
