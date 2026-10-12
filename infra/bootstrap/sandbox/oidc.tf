locals {
  oidc_host = "token.actions.githubusercontent.com"

  plan_role_name  = "iq-gha-plan"
  apply_role_name = "iq-gha-apply"

  # Pull requests and pushes to main may plan. Jobs that use a GitHub Environment
  # get an environment-based subject instead, so they cannot use this role.
  plan_subjects = flatten([
    for repo in var.plan_repositories : [
      "repo:${var.github_owner}/${repo}:pull_request",
      "repo:${var.github_owner}/${repo}:ref:refs/heads/main",
    ]
  ])

  # Only jobs in the apply repository that run in the protected environment may apply.
  apply_subject = "repo:${var.github_owner}/${var.apply_repository}:environment:${var.apply_environment}"

  plan_role_arn  = "arn:aws:iam::${var.account_id}:role/${local.plan_role_name}"
  apply_role_arn = "arn:aws:iam::${var.account_id}:role/${local.apply_role_name}"
}

# GitHub's OIDC provider. AWS validates GitHub's certificate through its own trusted
# CA store, so no thumbprint is pinned here.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

# ---------------------------------------------------------------------------
# Plan role: read-only, used by pull requests and main-branch runs.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_host}:sub"
      values   = local.plan_subjects
    }
  }
}

resource "aws_iam_role" "plan" {
  name                 = local.plan_role_name
  description          = "GitHub Actions read-only role for terraform plan (PRs and main)."
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# terraform plan takes a state lock, which writes a .tflock object next to the state.
data "aws_iam_policy_document" "plan_state_lock" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }

  statement {
    sid       = "ManageLockFiles"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "plan_state_lock" {
  name   = "terraform-state-lock"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_state_lock.json
}

# ---------------------------------------------------------------------------
# Apply role: admin inside the sandbox, only from the protected "demo" environment.
# SCPs from the management account still apply on top of this.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = [local.apply_subject]
    }
  }
}

resource "aws_iam_role" "apply" {
  name                 = local.apply_role_name
  description          = "GitHub Actions role for terraform apply/destroy from the demo environment."
  assume_role_policy   = data.aws_iam_policy_document.apply_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "apply_admin" {
  #checkov:skip=CKV_AWS_274:Isolated sandbox account; SCPs and the inline deny below bound this role.
  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# CI must never be able to weaken its own access path or the state bucket.
data "aws_iam_policy_document" "apply_protect_bootstrap" {
  statement {
    sid    = "ProtectCiRoles"
    effect = "Deny"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DeleteRole",
      "iam:DeleteRolePermissionsBoundary",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePermissionsBoundary",
      "iam:PutRolePolicy",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole",
    ]
    resources = [local.plan_role_arn, local.apply_role_arn]
  }

  statement {
    sid    = "ProtectOidcProvider"
    effect = "Deny"
    actions = [
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
    ]
    resources = [aws_iam_openid_connect_provider.github.arn]
  }

  statement {
    sid    = "ProtectStateBucket"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
    ]
    resources = [aws_s3_bucket.state.arn]
  }
}

resource "aws_iam_role_policy" "apply_protect_bootstrap" {
  name   = "protect-bootstrap"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_protect_bootstrap.json
}
