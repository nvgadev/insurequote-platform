variable "aws_profile" {
  description = "AWS CLI profile for the management account."
  type        = string
  default     = "iq-mgmt"
}

variable "management_account_id" {
  description = "AWS Organizations management account ID (aws sts get-caller-identity --profile iq-mgmt)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "management_account_id must be a 12-digit AWS account ID."
  }
}

variable "sandbox_account_id" {
  description = "Account the guardrails and budget apply to."
  type        = string
  default     = "352329340795"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.sandbox_account_id))
    error_message = "sandbox_account_id must be a 12-digit AWS account ID."
  }
}

variable "owner" {
  description = "Value for the owner tag."
  type        = string
  default     = "gopi"
}

variable "allowed_regions" {
  description = "Regions the sandbox may use for regional services."
  type        = list(string)
  default     = ["us-east-1"]
}

variable "bedrock_regions" {
  description = <<-EOT
    Regions Bedrock may run in. Claude models are called through US cross-region
    inference profiles, which route requests across these regions.
  EOT
  type        = list(string)
  default     = ["us-east-1", "us-east-2", "us-west-2"]
}

variable "create_budget" {
  description = "Create the monthly budget. Set false if you keep a budget made in the console."
  type        = bool
  default     = true
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget for the sandbox account, in USD."
  type        = number
  default     = 75
}

variable "budget_alert_thresholds_percent" {
  description = "Actual-spend alert thresholds as a percent of the budget ($30, $50, $75 at the default)."
  type        = list(number)
  default     = [40, 67, 100]
}

variable "budget_alert_emails" {
  description = "Email addresses that receive budget alerts."
  type        = list(string)
  default     = []

  validation {
    condition     = !var.create_budget || length(var.budget_alert_emails) > 0
    error_message = "Set at least one budget_alert_emails entry when create_budget is true."
  }
}
