provider "aws" {
  region  = "us-east-1"
  profile = var.aws_profile

  # Organizations and Budgets calls must run in the management account.
  allowed_account_ids = [var.management_account_id]

  default_tags {
    tags = {
      project    = "insurequote"
      env        = "org"
      owner      = var.owner
      managed-by = "terraform"
    }
  }
}
