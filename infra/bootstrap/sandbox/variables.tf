variable "region" {
  description = "AWS region for the state bucket and the platform."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile (IAM Identity Center) for the sandbox account."
  type        = string
  default     = "iq-sandbox"
}

variable "account_id" {
  description = "Sandbox AWS account ID. Terraform refuses to run anywhere else."
  type        = string
  default     = "352329340795"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "owner" {
  description = "Value for the owner tag."
  type        = string
  default     = "gopi"
}

variable "github_owner" {
  description = "GitHub user or organization that owns the repositories."
  type        = string
  default     = "nvgadev"
}

variable "plan_repositories" {
  description = <<-EOT
    Repository names (wildcards allowed) whose pull requests and main-branch runs
    may assume the read-only plan role.
  EOT
  type        = list(string)
  default     = ["insurequote-*", "terraform-aws-modules"]
}

variable "apply_repository" {
  description = "The only repository allowed to assume the apply role."
  type        = string
  default     = "insurequote-platform"
}

variable "apply_environment" {
  description = "GitHub Environment (with required reviewers) that gates the apply role."
  type        = string
  default     = "demo"
}

variable "state_bucket_name" {
  description = "Override for the state bucket name. Defaults to iq-tfstate-<account>-<region>."
  type        = string
  default     = null
}

variable "noncurrent_state_retention_days" {
  description = "Days to keep old versions of state files."
  type        = number
  default     = 90
}
