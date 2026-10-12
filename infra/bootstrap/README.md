# Bootstrap

Run once, by hand, before any other InsureQuote Terraform. It creates everything
CI needs to reach AWS safely, and the guardrails that keep the sandbox cheap.

| Stack | Account | Creates | State |
| --- | --- | --- | --- |
| `sandbox/` | insurequote-sandbox (352329340795) | State bucket, GitHub OIDC provider, `iq-gha-plan` and `iq-gha-apply` roles | S3 (after first apply) |
| `org/` | Management account | `iq-sandbox-guardrails` SCP, `iq-sandbox-monthly` budget | Local, git-ignored |

## What each piece does

- **State bucket** `iq-tfstate-352329340795-us-east-1`: versioned, KMS-encrypted, public access blocked, TLS only. Locking uses S3 lock files (`use_lockfile`), so there is no DynamoDB table.
- **`iq-gha-plan`**: read-only. Any `nvgadev/insurequote-*` repo or `nvgadev/terraform-aws-modules` can assume it from a pull request or from `main`.
- **`iq-gha-apply`**: admin inside the sandbox, but only from `nvgadev/insurequote-platform` jobs running in the `demo` environment, which needs your approval. An inline deny stops it from editing the CI roles, the OIDC provider or the state bucket.
- **SCP**: regional services only in us-east-1 (Bedrock also in us-east-2 and us-west-2 for cross-region inference); no GPU, bare-metal or 4xlarge+ instances; RDS only `db.t3`/`db.t4g`; CloudTrail cannot be stopped or deleted; the root user is blocked; the account cannot leave the organization. `OrganizationAccountAccessRole` is exempt so the management account can always repair things.
- **Budget**: $75 per month for the sandbox account, emails at 40%, 67% and 100% of actual spend and when the forecast passes 100%.

## Before you start

- `aws sts get-caller-identity --profile iq-sandbox` shows account `352329340795`.
- `gh auth status` shows `nvgadev`.
- Git identity is set (`git config --global user.name` / `user.email`).

## Step 1: Create the repository

```bash
mkdir -p ~/projects && cd ~/projects        # or wherever you keep code
unzip ~/Downloads/insurequote-platform-bootstrap.zip
cd insurequote-platform

git init -b main
git add .
git commit -m "feat(bootstrap): state bucket, GitHub OIDC roles, sandbox guardrails"
gh repo create nvgadev/insurequote-platform --public \
  --description "InsureQuote platform: EKS, GitOps and five DevOps + AI projects" \
  --source=. --remote=origin --push
```

## Step 2: Sandbox stack (state bucket and OIDC roles)

```bash
aws sso login --profile iq-sandbox
cd infra/bootstrap/sandbox

terraform init
terraform plan -out tfplan     # expect 14 resources to add
terraform apply tfplan
```

Move the state into the bucket you just created:

```bash
cp backend.tf.example backend.tf
terraform init -migrate-state   # answer "yes"
terraform plan                  # must say "No changes"
rm -f terraform.tfstate terraform.tfstate.backup tfplan
git add backend.tf .terraform.lock.hcl
git commit -m "chore(bootstrap): move sandbox state to S3"
git push
```

## Step 3: GitHub settings for the repo

```bash
REPO=nvgadev/insurequote-platform

# Repository variables (role ARNs are not secrets)
gh variable set AWS_PLAN_ROLE_ARN  -R $REPO --body "$(terraform output -raw plan_role_arn)"
gh variable set AWS_APPLY_ROLE_ARN -R $REPO --body "$(terraform output -raw apply_role_arn)"
gh variable set TF_STATE_BUCKET    -R $REPO --body "$(terraform output -raw state_bucket)"

# "demo" environment: you must approve every job that uses it, and only main may deploy
USER_ID=$(gh api user --jq .id)
gh api -X PUT repos/$REPO/environments/demo --input - <<EOF
{
  "reviewers": [{ "type": "User", "id": $USER_ID }],
  "prevent_self_review": false,
  "deployment_branch_policy": { "protected_branches": false, "custom_branch_policies": true }
}
EOF
gh api -X POST repos/$REPO/environments/demo/deployment-branch-policies -f name=main -f type=branch
```

## Step 4: Management account access

1. Sign in to the management account console, region **us-east-1**.
2. **IAM Identity Center → AWS accounts** → select the **management account** → **Assign users or groups** → `gopi` → permission set `AdministratorAccess` → **Submit**.
3. Add a CLI profile (reuses the `iq` SSO session):

   ```bash
   aws configure sso --profile iq-mgmt
   # session: iq, pick the management account, role AdministratorAccess, region us-east-1
   aws sts get-caller-identity --profile iq-mgmt
   ```

4. Turn on SCPs for the organization (once; an "already enabled" error is fine):

   ```bash
   ROOT_ID=$(aws organizations list-roots --profile iq-mgmt --query 'Roots[0].Id' --output text)
   aws organizations enable-policy-type --root-id "$ROOT_ID" \
     --policy-type SERVICE_CONTROL_POLICY --profile iq-mgmt
   ```

## Step 5: Org stack (guardrails and budget)

If you already created a budget in the console, delete it first (Billing and Cost
Management → Budgets) or set `create_budget = false`, so you don't get duplicate emails.

```bash
cd ../org
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: management_account_id and budget_alert_emails

terraform init
terraform plan -out tfplan     # expect 3 resources with the budget, 2 without
terraform apply tfplan
terraform output guardrails_policy_size_chars   # must be under 5120
rm -f tfplan
```

## Step 6: Verify

```bash
# Allowed region works
aws ec2 describe-vpcs --region us-east-1 --profile iq-sandbox --query 'Vpcs[].VpcId'

# Other regions are blocked: expect "explicit deny in a service control policy"
aws ec2 describe-vpcs --region eu-west-1 --profile iq-sandbox
```

Then in GitHub: **Actions → oidc-smoke-test → Run workflow** on `main`.
The plan job runs straight away; the apply job waits for your approval, then checks
that eu-west-1 is denied. Both green means OIDC, both roles and the SCP all work.

## Changing or removing

- Re-run `terraform plan` / `apply` in the same folder; bootstrap is never run by CI.
- The state bucket has `prevent_destroy`. To delete it you must remove that line on purpose.
- To lift a guardrail temporarily, edit `org/scp.tf` and apply; don't detach the policy in the console.
