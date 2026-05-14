# DataVault Technologies — Compliance Audit Trail API

FCA-compliant audit trail platform for UK financial services firms.
Built with Python FastAPI.

## Local Development

```bash
cd app
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

API docs: http://localhost:8000/docs
Health: http://localhost:8000/health
Readiness: http://localhost:8000/ready

## Authentication

All endpoints except `/health` and `/ready` require:

```bash
x-api-key: datavault-dev-key
```

## Running Tests

```bash
pip install pytest httpx
pytest tests/ -v
```

## Your Task

You do NOT modify the application code.

Your job is to:
1. Write the Dockerfile
2. Write Kubernetes manifests (Deployment, Service, ConfigMap, Secret, HPA)
3. Set up ArgoCD to watch the k8s/ manifests folder
4. Write a GitHub Actions CI pipeline that builds and pushes the image to ECR
5. Use Terraform to provision the EC2 instance and ECR repository

See the case study document for full instructions.

## Key Endpoints for Kubernetes Probes

```yaml
# Use these in your Deployment manifest:
livenessProbe:
  httpGet:
    path: /health
    port: 8000

readinessProbe:
  httpGet:
    path: /health
    port: 8000
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| APP_ENV | development | Environment name (production/staging/development) |
| API_KEY | datavault-dev-key | Comma-separated list of valid API keys |
| LOG_LEVEL | info | Log level |

In Kubernetes, set these via ConfigMap (APP_ENV, LOG_LEVEL) and Secret (API_KEY).
