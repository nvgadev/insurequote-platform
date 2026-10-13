# Step 2 of the bootstrap: after the first apply creates the bucket, copy this file to
# backend.tf and run `terraform init -migrate-state` to move local state into S3.
terraform {
  backend "s3" {
    bucket       = "iq-tfstate-352329340795-us-east-1"
    key          = "bootstrap/sandbox/terraform.tfstate"
    region       = "us-east-1"
    profile      = "iq-sandbox"
    encrypt      = true
    use_lockfile = true
  }
}
