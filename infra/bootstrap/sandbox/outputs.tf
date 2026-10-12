output "state_bucket" {
  description = "S3 bucket that holds Terraform state for all InsureQuote stacks."
  value       = aws_s3_bucket.state.bucket
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "plan_role_arn" {
  description = "Role for terraform plan. Set as the AWS_PLAN_ROLE_ARN repository variable."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Role for terraform apply. Set as the AWS_APPLY_ROLE_ARN repository variable."
  value       = aws_iam_role.apply.arn
}

output "plan_role_subjects" {
  description = "OIDC subjects allowed to assume the plan role."
  value       = local.plan_subjects
}

output "apply_role_subject" {
  description = "OIDC subject allowed to assume the apply role."
  value       = local.apply_subject
}
