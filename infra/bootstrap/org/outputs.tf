output "guardrails_policy_id" {
  description = "ID of the sandbox service control policy."
  value       = aws_organizations_policy.sandbox_guardrails.id
}

output "guardrails_policy_size_chars" {
  description = "SCP document size. AWS allows at most 5,120 characters."
  value       = length(data.aws_iam_policy_document.sandbox_guardrails.minified_json)
}

output "budget_name" {
  description = "Name of the monthly sandbox budget, if created."
  value       = try(aws_budgets_budget.sandbox_monthly[0].name, null)
}
