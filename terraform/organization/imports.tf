import {
  to = aws_organizations_organization.foundation
  id = "o-n0evqvouxs"
}

import {
  to = aws_iam_organizations_features.centralized_root_access
  id = "o-n0evqvouxs"
}

import {
  to = aws_organizations_organizational_unit.workloads
  id = "ou-y37x-pfae3qwq"
}

import {
  to = aws_organizations_account.foundation["workloads-prod"]
  id = "134604497564"
}

import {
  to = aws_organizations_account.foundation["workloads-uat"]
  id = "732006412638"
}

import {
  to = aws_organizations_policy.default_security
  id = "p-y89j26g0"
}

import {
  to = aws_organizations_policy_attachment.default_security_root
  id = "r-y37x:p-y89j26g0"
}

import {
  to = aws_organizations_policy_attachment.full_aws_access["management"]
  id = "357964519547:p-FullAWSAccess"
}

import {
  to = aws_organizations_policy_attachment.full_aws_access["workloads-prod"]
  id = "134604497564:p-FullAWSAccess"
}

import {
  to = aws_organizations_policy_attachment.full_aws_access["root"]
  id = "r-y37x:p-FullAWSAccess"
}

import {
  to = aws_organizations_policy_attachment.full_aws_access["workloads-uat"]
  id = "732006412638:p-FullAWSAccess"
}

import {
  to = aws_organizations_policy_attachment.full_aws_access["workloads"]
  id = "ou-y37x-pfae3qwq:p-FullAWSAccess"
}

import {
  to = aws_ssoadmin_permission_set.this["bootstrap-administrator"]
  id = "arn:aws:sso:::permissionSet/ssoins-7223f0f0b061900d/ps-7223b58c497d8681,arn:aws:sso:::instance/ssoins-7223f0f0b061900d"
}

import {
  to = aws_ssoadmin_permission_set.this["read-only"]
  id = "arn:aws:sso:::permissionSet/ssoins-7223f0f0b061900d/ps-7223ec2a3cf4825b,arn:aws:sso:::instance/ssoins-7223f0f0b061900d"
}

import {
  to = aws_ssoadmin_managed_policy_attachment.this["bootstrap-administrator"]
  id = "arn:aws:iam::aws:policy/AdministratorAccess,arn:aws:sso:::permissionSet/ssoins-7223f0f0b061900d/ps-7223b58c497d8681,arn:aws:sso:::instance/ssoins-7223f0f0b061900d"
}

import {
  to = aws_ssoadmin_managed_policy_attachment.this["read-only"]
  id = "arn:aws:iam::aws:policy/ReadOnlyAccess,arn:aws:sso:::permissionSet/ssoins-7223f0f0b061900d/ps-7223ec2a3cf4825b,arn:aws:sso:::instance/ssoins-7223f0f0b061900d"
}

import {
  to = aws_ssoadmin_account_assignment.this["management:bootstrap-administrator"]
  id = "c44824a8-e0c1-70ef-836c-9ee7fc11c9bf,USER,357964519547,AWS_ACCOUNT,arn:aws:sso:::permissionSet/ssoins-7223f0f0b061900d/ps-7223b58c497d8681,arn:aws:sso:::instance/ssoins-7223f0f0b061900d"
}

import {
  to = aws_ssoadmin_account_assignment.this["management:read-only"]
  id = "c44824a8-e0c1-70ef-836c-9ee7fc11c9bf,USER,357964519547,AWS_ACCOUNT,arn:aws:sso:::permissionSet/ssoins-7223f0f0b061900d/ps-7223ec2a3cf4825b,arn:aws:sso:::instance/ssoins-7223f0f0b061900d"
}

import {
  to = aws_ssoadmin_account_assignment.this["workloads-prod:bootstrap-administrator"]
  id = "c44824a8-e0c1-70ef-836c-9ee7fc11c9bf,USER,134604497564,AWS_ACCOUNT,arn:aws:sso:::permissionSet/ssoins-7223f0f0b061900d/ps-7223b58c497d8681,arn:aws:sso:::instance/ssoins-7223f0f0b061900d"
}

import {
  to = aws_ssoadmin_account_assignment.this["workloads-prod:read-only"]
  id = "c44824a8-e0c1-70ef-836c-9ee7fc11c9bf,USER,134604497564,AWS_ACCOUNT,arn:aws:sso:::permissionSet/ssoins-7223f0f0b061900d/ps-7223ec2a3cf4825b,arn:aws:sso:::instance/ssoins-7223f0f0b061900d"
}

import {
  to = aws_ssoadmin_account_assignment.this["workloads-uat:bootstrap-administrator"]
  id = "c44824a8-e0c1-70ef-836c-9ee7fc11c9bf,USER,732006412638,AWS_ACCOUNT,arn:aws:sso:::permissionSet/ssoins-7223f0f0b061900d/ps-7223b58c497d8681,arn:aws:sso:::instance/ssoins-7223f0f0b061900d"
}

import {
  to = aws_ssoadmin_account_assignment.this["workloads-uat:read-only"]
  id = "c44824a8-e0c1-70ef-836c-9ee7fc11c9bf,USER,732006412638,AWS_ACCOUNT,arn:aws:sso:::permissionSet/ssoins-7223f0f0b061900d/ps-7223ec2a3cf4825b,arn:aws:sso:::instance/ssoins-7223f0f0b061900d"
}
