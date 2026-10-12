terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # This stack runs rarely, by hand, against the management account.
  # Its state stays local (git-ignored); it holds no secrets.
}
