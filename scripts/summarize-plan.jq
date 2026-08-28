def scope_for_address($address):
  if $root == "terraform/platform" then
    if ($address | test("^module\\.(foundation_plan_production|workloads_production)(\\.|\\[|$)")) then
      "production"
    elif ($address | test("^module\\.(foundation_plan_uat|workloads_uat)(\\.|\\[|$)")) then
      "uat"
    else
      "deployment"
    end
  elif $root == "terraform/github" then
    "github"
  else
    "management"
  end;

[
  .resource_changes[]?
  | select(.change.actions != ["no-op"])
  | select(.change.actions != ["read"])
  | {
      address,
      actions: .change.actions,
      scope: scope_for_address(.address)
    }
]
