provider "aws" {
  region  = var.region
  profile = var.aws_profile

  # Refuse to run against any account other than the sandbox.
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      project    = "insurequote"
      env        = "bootstrap"
      owner      = var.owner
      managed-by = "terraform"
      repo       = "${var.github_owner}/insurequote-platform"
    }
  }
}
