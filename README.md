# DataVault GitOps Platform

> Kubernetes-based GitOps deployment platform for DataVault Technologies — a Manchester-based FCA-regulated SaaS company. Every production change is a Git commit. Every deployment is automated. Every crashed pod restarts itself.

---

## The Problem This Solves

DataVault's previous deployment process: an engineer SSHes into three bare-metal servers in sequence, pulls a Docker image, restarts containers. 40 minutes per deployment. No rollback. No audit trail. No self-healing.

On 14 February 2025, a botched deployment caused 2 hours 33 minutes of degraded service for a Tier 1 UK bank. The bank's FCA compliance team asked: *"Who deployed what and when?"* DataVault could not answer. A 90-day remediation plan was issued. The contract — worth £340,000/year — is at risk.

This platform is the remediation.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS (eu-west-2)                      │
│                                                             │
│   ┌─────────────┐          ┌──────────────────────────┐    │
│   │  S3 Bucket  │          │     EC2 t3.small          │    │
│   │  (tfstate)  │          │                          │    │
│   │  KMS-enc    │          │  ┌────────────────────┐  │    │
│   │  Versioned  │          │  │  k3s (Kubernetes)  │  │    │
│   └─────────────┘          │  │                    │  │    │
│                            │  │  ┌──────────────┐  │  │    │
│   ┌─────────────┐          │  │  │  ArgoCD      │  │  │    │
│   │  ECR Repo   │◄─────────│  │  ├──────────────┤  │  │    │
│   │  Immutable  │  pull    │  │  │  DataVault   │  │  │    │
│   │  KMS-enc    │  images  │  │  │  API (2 pods)│  │  │    │
│   └─────────────┘          │  │  └──────────────┘  │  │    │
│                            │  └────────────────────┘  │    │
│   ┌─────────────┐          │                          │    │
│   │  Secrets    │          │  IAM Role (no keys)      │    │
│   │  Manager    │          │  IMDSv2 enforced          │    │
│   │  SSH key    │          │  EBS encrypted (CMK)     │    │
│   └─────────────┘          └──────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
         ▲
         │ GitOps sync
         │
┌────────┴────────┐
│   GitHub Repo   │
│                 │
│  k8s/           │◄── ArgoCD watches this
│  terraform/     │
│  app/           │
│  .github/       │◄── CI pipeline triggers here
└─────────────────┘
```

**Data flow:**
1. Engineer pushes code to GitHub
2. GitHub Actions builds Docker image, pushes to ECR, updates the k8s manifest
3. ArgoCD detects the manifest change and syncs the cluster
4. Kubernetes rolls out the new version — zero downtime
5. The Git commit log is the FCA audit trail

---

## Repository Structure

```
datavault-gitops/
├── terraform/
│   ├── bootstrap/          # One-time: creates S3 state bucket
│   │   ├── main.tf
│   │   ├── variable.tf
│   │   ├── output.tf
│   │   └── terraform.tfvars
│   ├── main.tf             # EC2, ECR, IAM, Security Group
│   ├── kms.tf              # Customer-managed KMS keys
│   ├── ssm.tf              # SSH keypair + Secrets Manager
│   ├── instID.tf           # Dynamic AMI data source
│   ├── provider.tf         # AWS + TLS provider config
│   ├── backend.tf          # S3 remote state config
│   ├── variable.tf         # All input variables
│   ├── output.tf           # EC2 IP, ECR URL, Secret ARN
│   ├── terraform.tfvars    # Your values (gitignored)
│   └── user_data.tftpl     # EC2 bootstrap script template
├── app/
│   └── datavault-api/
│       ├── app/
│       │   ├── main.py         # FastAPI audit trail application
│       │   ├── requirements.txt
│       │   ├── Dockerfile      # Multi-stage, non-root container
│       │   └── .dockerignore
│       └── tests/
│           └── test_main.py
├── k8s/                    # Kubernetes manifests (Day 3)
├── .github/workflows/      # GitHub Actions CI pipeline (Day 5)
├── .tfsec/config.yml       # tfsec security scan config
├── JOURNAL.md              # Daily engineering log
└── README.md               # This file
```

---

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Terraform | >= 1.10.0 | Infrastructure provisioning |
| AWS CLI | >= 2.0 | AWS authentication and ECR login |
| tflint | latest | Terraform linting |
| tfsec | latest | Terraform security scanning |
| kubectl | >= 1.28 | Kubernetes cluster management |
| Docker | >= 24.0 | Container build and local testing |
| k3s | latest | Lightweight Kubernetes (installed on EC2) |

---

## Kubernetes Cluster Setup (k3s)

k3s is installed directly on the EC2 instance. It turns the bare Ubuntu server into a fully certified Kubernetes cluster with a single command.

### Install k3s on the EC2 instance

SSH into the instance first (see [Connecting to the EC2 Instance](#connecting-to-the-ec2-instance)), then:

```bash
curl -sfL https://get.k3s.io | sh -
```

Configure kubectl without sudo:

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown ubuntu:ubuntu ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
```

Verify the cluster is healthy:

```bash
kubectl get nodes
# NAME          STATUS   ROLES                  AGE   VERSION
# ip-172-x-x-x  Ready    control-plane,master   60s   v1.x.x+k3s1

kubectl get pods --all-namespaces
# All pods should be Running or Completed
```

### Configure kubectl on your local machine

```bash
# Copy kubeconfig from EC2
scp -i ~/.ssh/datavault-key.pem ubuntu@<ec2_public_ip>:~/.kube/config ~/.kube/datavault-config

# Replace localhost with EC2 public IP (Git Bash / WSL)
sed -i 's/127\.0\.0\.1:6443/<ec2_public_ip>:6443/g' ~/.kube/datavault-config

# Merge with existing kubeconfigs
export KUBECONFIG=~/.kube/config:~/.kube/datavault-config

# Rename context and switch to it
kubectl config rename-context default datavault-k3s
kubectl config use-context datavault-k3s

# Verify
kubectl get nodes
```

---

## The DataVault Application

The application is a FastAPI service simulating DataVault's FCA compliance audit trail platform.

### Application endpoints

| Endpoint | Auth | Purpose |
|---|---|---|
| `GET /health` | None | Kubernetes liveness probe |
| `GET /ready` | None | Kubernetes readiness probe |
| `GET /api/audit` | x-api-key header | List audit trail entries |
| `POST /api/audit` | x-api-key header | Create audit entry |
| `GET /api/compliance` | x-api-key header | List compliance records |
| `GET /api/clients` | x-api-key header | List client accounts |
| `GET /api/deployment/status` | None | Current version and pod name |
| `GET /docs` | None | Auto-generated Swagger UI |

### Build and run locally

```bash
cd app/datavault-api/app

docker build -t datavault-api:1.0.0 .

docker run -d -p 8000:8000 \
  -e APP_ENV=local \
  -e API_KEY=datavault-dev-key \
  --name datavault-api \
  datavault-api:1.0.0

# Test
curl http://localhost:8000/health
curl -H "x-api-key: datavault-dev-key" http://localhost:8000/api/audit

# Interactive docs
open http://localhost:8000/docs
```

### Dockerfile design decisions

**Multi-stage build** — builder stage installs dependencies, runtime stage contains only what's needed to run. Reduces image size from ~1GB to ~180MB and removes build tools from the attack surface.

**Non-root user** — runs as `appuser` (uid 10001). If the container is compromised, the attacker has no root privileges on the host.

**uvicorn, not gunicorn** — FastAPI is ASGI. gunicorn is WSGI. They are incompatible. uvicorn is the correct server. Using gunicorn flags with uvicorn causes an immediate container exit with code 2.

**Pinned versions** — `fastapi==0.115.5`, not `fastapi>=2.0`. Every build is identical and reproducible.

---

### Step 1 — Configure AWS credentials

```bash
aws configure
# Enter your Access Key ID, Secret Access Key
# Default region: eu-west-2
# Default output: json

# Verify
aws sts get-caller-identity
```

### Step 2 — Run security checks before touching AWS

This project follows a **shift-left security** approach — all security scanning happens at the code stage, before any infrastructure is created. See the [Security section](#security--shift-left-approach) for full details.

```bash
# Lint check
tflint --chdir=terraform/bootstrap
tflint --chdir=terraform

# Security scan
tfsec terraform/bootstrap --format lovely
tfsec terraform --format lovely
```

Both must return zero issues before proceeding.

### Step 3 — Bootstrap (create the S3 state bucket)

The bootstrap workspace is run **once only**. It creates the S3 bucket that stores Terraform's remote state. It intentionally uses local state because you cannot store state in a bucket you are in the process of creating.

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

Note the output value for `state_bucket_name`. You will need it in the next step.

```
Outputs:
state_bucket_name = "datavault-tfstate-dev-a1b2c3d4"
kms_key_arn       = "arn:aws:kms:eu-west-2:123456789:key/..."
```

### Step 4 — Configure the remote backend

Open `terraform/backend.tf` and replace the bucket name with the value from Step 3:

```hcl
terraform {
  backend "s3" {
    bucket       = "datavault-tfstate-dev-a1b2c3d4"  # from bootstrap output
    key          = "datavault/dev/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
```

### Step 5 — Configure your variables

Copy the example and fill in your values:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`:

```hcl
environment      = "dev"
aws_region       = "eu-west-2"
project_name     = "datavault"
allowed_ssh_cidr = "YOUR.IP.ADDRESS/32"  # get yours: curl ifconfig.me
```

> `terraform.tfvars` is gitignored. Never commit it.

### Step 6 — Apply the main infrastructure

```bash
cd terraform
terraform init      # connects to S3 backend for the first time
terraform plan      # review what will be created — read this carefully
terraform apply     # type 'yes' to confirm
```

Expected output:

```
Apply complete! Resources: 19 added, 0 changed, 0 destroyed.

Outputs:
aws_ecr_repository_name = "datavault-api"
aws_ecr_repository_url  = "123456789.dkr.ecr.eu-west-2.amazonaws.com/datavault-api"
ec2_instance_id         = "i-0abc123def456789"
ec2_public_id           = "18.x.x.x"
ssh_key_secret_arn      = "arn:aws:secretsmanager:eu-west-2:..."
```

Save the `aws_ecr_repository_url` and `ec2_public_id` values.

---

## Connecting to the EC2 Instance

The SSH private key is stored in AWS Secrets Manager — not on any engineer's local filesystem. This is intentional. See [Why Secrets Manager for the SSH key](#why-secrets-manager-for-the-ssh-key) for the reasoning.

### Retrieve the private key

```bash
aws secretsmanager get-secret-value \
  --secret-id datavault/dev-deployer \
  --region eu-west-2 \
  --query SecretString \
  --output text > ~/.ssh/datavault-key.pem
```

**What this command does:**
- `get-secret-value` — calls the Secrets Manager API
- `--secret-id datavault/dev-deployer` — the name we gave the secret in Terraform
- `--query SecretString` — extracts only the secret value (the PEM key), not the metadata wrapper
- `--output text` — outputs raw text, not JSON
- `> ~/.ssh/datavault-key.pem` — writes the PEM key to a local file

### Set correct file permissions

```bash
chmod 600 ~/.ssh/datavault-key.pem
```

SSH will refuse to use a private key file that is readable by other users. `600` means only the file owner can read and write it.

### SSH into the instance

```bash
ssh -i ~/.ssh/datavault-key.pem ubuntu@<ec2_public_ip>
```

Replace `<ec2_public_ip>` with the `ec2_public_id` value from `terraform output`.

Expected result:

```
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 6.8.0-1053-aws x86_64)
ubuntu@ip-172-x-x-x:~$
```

### Why Secrets Manager for the SSH key

The traditional approach is to generate an SSH key pair locally and reference the public key in Terraform. This has two problems:

1. The private key lives on one engineer's laptop. If that laptop is lost or the engineer leaves, access is gone or must be revoked manually.
2. There is no audit trail. You cannot tell who used the key, when, or from where.

With Secrets Manager:
- The key is generated by Terraform (`tls_private_key` resource) and stored immediately in Secrets Manager — it never touches the operator's filesystem during provisioning
- Any authorised team member can retrieve it using the AWS CLI command above
- Every retrieval is logged in AWS CloudTrail — you have a full audit trail of who accessed the key and when
- Access is controlled by IAM — you can revoke access for a specific user without changing the key itself
- The key is encrypted at rest using a customer-managed KMS key

---

## Security — Shift-Left Approach

### What is shift-left security?

Shift-left means moving security checks earlier in the development process — to the left on the timeline. Instead of discovering security misconfigurations after deployment (or worse, during an incident or audit), you catch them at the code writing stage.

```
Traditional approach:
  Write code → Deploy → Discover vulnerability → Patch → Redeploy
                                    ↑
                              expensive, risky

Shift-left approach:
  Write code → Scan → Fix → Deploy
                  ↑
            cheap, fast, safe
```

For DataVault specifically, this matters beyond just good engineering practice. DataVault's clients are FCA-regulated financial firms. A security misconfiguration in DataVault's infrastructure is not just a technical problem — it is a compliance failure that can trigger regulatory action against DataVault's clients. Catching it before deployment is the only acceptable approach.

### Tools used

**tflint** — static analysis for Terraform code quality:
- Catches undeclared provider dependencies
- Flags unused variables
- Enforces type constraints on variables
- Run: `tflint --chdir=terraform`

**tfsec** — static analysis for Terraform security posture:
- Checks against AWS security benchmarks and CIS controls
- Maps findings to CVE-style IDs for traceability
- Severity levels: CRITICAL, HIGH, MEDIUM, LOW
- Run: `tfsec terraform --format lovely`

### Findings and resolutions

#### HIGH — IMDSv2 not enforced (`aws-ec2-enforce-http-token-imds`)

**What the risk is:** The EC2 Instance Metadata Service (IMDS) is an endpoint at `http://169.254.169.254` that any process on the instance can query to retrieve the instance's IAM credentials. IMDSv1 requires no authentication — any process, including malicious code injected via an application vulnerability, can hit that endpoint and steal the IAM role's credentials. This is a known attack vector (SSRF — Server-Side Request Forgery).

**Resolution:** Added `metadata_options` block to the EC2 instance:

```hcl
metadata_options {
  http_tokens                 = "required"   # IMDSv2 — session token required
  http_put_response_hop_limit = 1            # blocks containers from reaching host IMDS
  http_endpoint               = "enabled"
}
```

`http_put_response_hop_limit = 1` is a defence-in-depth measure: it limits metadata responses to one network hop, meaning containers running inside k3s cannot reach the host EC2 metadata endpoint. A compromised container cannot steal the EC2 IAM role credentials.

---

#### HIGH — Root EBS volume not encrypted (`aws-ec2-enable-at-rest-encryption`)

**What the risk is:** The root volume contains the OS, k3s binaries, ArgoCD configuration, and potentially cached secrets. An unencrypted EBS volume can be detached from the instance and mounted on another EC2 instance, making all data readable without any authentication. EBS snapshots of unencrypted volumes are also unencrypted.

**Resolution:** Added encryption to the `root_block_device` block using the application CMK:

```hcl
root_block_device {
  volume_size = var.ec2_volume_size
  volume_type = var.ec2_volume_type
  encrypted   = true
  kms_key_id  = aws_kms_key.app.arn
}
```

Using a CMK (rather than the AWS-managed default key) means every encryption and decryption operation is logged in CloudTrail, and the key can be disabled instantly if the instance is compromised.

---

#### HIGH — ECR image tags mutable (`aws-ecr-enforce-immutable-repository`)

**What the risk is:** With mutable tags, an attacker (or an accidental CI pipeline misconfiguration) can push a new image with an existing tag — for example, overwriting `v1.2.3` with a compromised image. ArgoCD would then deploy the compromised image without any indication that the image content had changed. The tag looks the same; the image is not.

**Resolution:** Changed the default to `IMMUTABLE` and added a validation rule:

```hcl
variable "immutability" {
  default = "IMMUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.immutability)
    error_message = "immutability must be MUTABLE or IMMUTABLE."
  }
}
```

**Workflow implication:** With immutable tags, the CI pipeline must push a unique tag for every image. We use the Git commit SHA (e.g., `abc1234`). This is better practice anyway — every image is traceable to an exact commit in the audit trail.

---

#### LOW — Secrets Manager using AWS-managed key (`aws-ssm-secret-use-customer-key`)

**What the risk is:** Using the AWS-managed default key means AWS controls key rotation and access auditing. You cannot see who decrypted the secret, you cannot revoke the key independently of the secret, and you cannot enforce your own rotation schedule.

**Resolution:** Created a CMK in `kms.tf` and referenced it:

```hcl
resource "aws_secretsmanager_secret" "ssh_key" {
  kms_key_id = aws_kms_key.app.arn
  ...
}
```

---

#### LOW — ECR not encrypted with CMK (`aws-ecr-repository-customer-key`)

**What the risk is:** Same principle as above — Docker images stored in ECR should be encrypted with a key you control, not a key AWS manages on your behalf.

**Resolution:** Added `encryption_configuration` to the ECR repository:

```hcl
encryption_configuration {
  encryption_type = "KMS"      # must be uppercase — tfsec is case-sensitive
  kms_key         = aws_kms_key.app.arn
}
```

Note: `encryption_type` must be `"KMS"` (uppercase). The AWS provider accepts lowercase but tfsec's pattern match requires uppercase. This was caught during the scan iteration.

---

### Final scan result

```
tfsec terraform --format lovely

passed    11
high       0
medium     0
low        0

No problems detected.
```

---

## Destroying the Infrastructure

When you are done with the environment, destroy resources in reverse order — main infrastructure first, then bootstrap.

```bash
# Destroy main infrastructure
cd terraform
terraform destroy

# Destroy bootstrap (S3 bucket)
# Note: S3 bucket must be empty before it can be destroyed
aws s3 rm s3://datavault-tfstate-dev-<suffix> --recursive
cd bootstrap
terraform destroy
```

> Deliverable 9 of the project requires demonstrating a clean `terraform destroy`. Keep this in mind for the final presentation.

---

## Resources

- [Terraform AWS Provider docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [k3s documentation](https://docs.k3s.io)
- [ArgoCD documentation](https://argo-cd.readthedocs.io)
- [FastAPI documentation](https://fastapi.tiangolo.com)
- [tfsec checks reference](https://aquasecurity.github.io/tfsec/latest/checks/aws/)
- [AWS IMDSv2 documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html)
- [FCA operational resilience requirements](https://www.fca.org.uk/firms/operational-resilience)
