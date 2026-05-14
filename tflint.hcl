###############################################################################
# .tflint.hcl
#
# PURPOSE: tflint configuration for the VaultBridge IaC project.
#
# tflint is a Terraform linter that catches issues terraform validate misses:
#   - Invalid instance types, AMI IDs, region names (AWS-specific rules)
#   - Deprecated syntax and provider-specific API mistakes
#   - Missing required declarations and naming convention violations
#
# It complements tfsec: tfsec focuses on security misconfigurations,
# tflint focuses on correctness and best-practice code quality.
#
# INSTALL:
#   choco install tflint                        # Windows
#   brew install tflint                         # macOS
#   docker pull ghcr.io/terraform-linters/tflint  # Docker
#
# INIT (downloads declared plugins — run once after cloning):
#   tflint --init
#
# RUN:
#   tflint --chdir=infra                        # Lint the infra workspace
#   tflint --chdir=bootstrap                    # Lint the bootstrap workspace
#   tflint --chdir=infra --format compact       # CI-friendly output
###############################################################################

# ── Core tflint behaviour ─────────────────────────────────────────────────────

config {
  # Fail if a called module has no source — catches incomplete module references.
  call_module_type = "local"
}

# ── Terraform built-in ruleset ────────────────────────────────────────────────
# Covers: deprecated syntax, required_providers hygiene, naming conventions,
# unused declarations, and missing variable descriptions.

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# ── AWS ruleset ───────────────────────────────────────────────────────────────
# Validates AWS-specific values against the actual AWS API:
#   - Invalid EC2 instance types (e.g. typo: "t3.mciro")
#   - Invalid AWS regions
#   - Deprecated resource types
#   - Invalid RDS instance classes

plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
