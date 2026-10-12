locals {
  # The break-glass role created with the member account is exempt, so the
  # management account can always repair the sandbox.
  break_glass_role = "arn:aws:iam::*:role/OrganizationAccountAccessRole"

  # Global or us-east-1-only services that must keep working whatever region a call names.
  # Based on the AWS example "Deny access to AWS based on the requested AWS Region".
  region_exempt_actions = [
    "account:*",
    "acm:*",
    "aws-marketplace:*",
    "aws-marketplace-management:*",
    "aws-portal:*",
    "bedrock:*",
    "billing:*",
    "budgets:*",
    "ce:*",
    "cloudfront:*",
    "config:*",
    "cur:*",
    "ec2:DescribeRegions",
    "freetier:*",
    "globalaccelerator:*",
    "health:*",
    "iam:*",
    "identitystore:*",
    "kms:*",
    "networkmanager:*",
    "organizations:*",
    "payments:*",
    "pricing:*",
    "route53:*",
    "route53domains:*",
    "s3:GetAccountPublic*",
    "s3:ListAllMyBuckets",
    "s3:PutAccountPublic*",
    "shield:*",
    "sso:*",
    "sts:*",
    "support:*",
    "tax:*",
    "trustedadvisor:*",
    "waf:*",
    "wafv2:*",
  ]

  # GPU, accelerator, bare-metal and very large instance types.
  denied_instance_types = [
    "*.metal*",
    "*.4xlarge",
    "*.8xlarge",
    "*.9xlarge",
    "*.12xlarge",
    "*.16xlarge",
    "*.18xlarge",
    "*.24xlarge",
    "*.32xlarge",
    "*.48xlarge",
    "dl*",
    "f*",
    "g*",
    "hpc*",
    "inf*",
    "p*",
    "trn*",
    "u-*",
    "vt*",
    "x*",
  ]
}

data "aws_iam_policy_document" "sandbox_guardrails" {
  statement {
    sid         = "DenyOutsideAllowedRegions"
    effect      = "Deny"
    not_actions = local.region_exempt_actions
    resources   = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalARN"
      values   = [local.break_glass_role]
    }
  }

  statement {
    sid       = "DenyBedrockOutsideUsInferenceRegions"
    effect    = "Deny"
    actions   = ["bedrock:*"]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.bedrock_regions
    }
  }

  statement {
    sid       = "DenyLargeOrAcceleratedInstances"
    effect    = "Deny"
    actions   = ["ec2:RunInstances"]
    resources = ["arn:aws:ec2:*:*:instance/*"]

    condition {
      test     = "StringLike"
      variable = "ec2:InstanceType"
      values   = local.denied_instance_types
    }
  }

  statement {
    sid       = "AllowOnlyBurstableRds"
    effect    = "Deny"
    actions   = ["rds:CreateDBInstance"]
    resources = ["*"]

    condition {
      test     = "StringNotLike"
      variable = "rds:DatabaseClass"
      values   = ["db.t3.*", "db.t4g.*"]
    }
  }

  statement {
    sid       = "ProtectAuditTrail"
    effect    = "Deny"
    actions   = ["cloudtrail:DeleteTrail", "cloudtrail:StopLogging"]
    resources = ["*"]

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalARN"
      values   = [local.break_glass_role]
    }
  }

  statement {
    sid       = "DenyRootUser"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalARN"
      values   = ["arn:aws:iam::*:root"]
    }
  }

  statement {
    sid       = "DenyLeavingOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]
  }
}

resource "aws_organizations_policy" "sandbox_guardrails" {
  name        = "iq-sandbox-guardrails"
  description = "InsureQuote sandbox: region lock, instance size limits, audit trail and root protection."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.sandbox_guardrails.json
}

resource "aws_organizations_policy_attachment" "sandbox_guardrails" {
  policy_id = aws_organizations_policy.sandbox_guardrails.id
  target_id = var.sandbox_account_id
}
