"""
DataVault Technologies — Audit Trail API Simulation

This service simulates the core DataVault compliance platform.
It captures and serves audit log entries for FCA-regulated financial firms.

Endpoints:
  GET /health    — liveness probe (is the app alive?)
  GET /ready     — readiness probe (is the app ready for traffic?)
  GET /audit     — returns simulated audit log entries
  GET /          — service info
"""

import os
import logging
from datetime import datetime, timezone
from flask import Flask, jsonify

# ── Logging ───────────────────────────────────────────────────────────────────
# Structured logging — every log line includes timestamp and level.
# In production this feeds into CloudWatch or a SIEM.
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(__name__)

# ── App Initialisation ────────────────────────────────────────────────────────
app = Flask(__name__)

# Read configuration from environment variables.
# These are injected by Kubernetes via ConfigMap and Secret — never hardcoded.
APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "development")
COMPANY_NAME = os.environ.get("COMPANY_NAME", "DataVault Technologies")
DB_HOST = os.environ.get("DB_HOST", "localhost")


# ── Routes ────────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    """Service information endpoint."""
    logger.info("Index endpoint called")
    return jsonify({
        "service": "DataVault Audit Trail API",
        "company": COMPANY_NAME,
        "version": APP_VERSION,
        "environment": ENVIRONMENT,
        "timestamp": datetime.now(timezone.utc).isoformat()
    })


@app.route("/health")
def health():
    """
    Liveness probe endpoint.

    Kubernetes calls this on a schedule. If it returns non-200,
    Kubernetes kills the pod and starts a new one.
    This answers: 'Is the application process alive?'
    """
    logger.info("Liveness probe called")
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }), 200


@app.route("/ready")
def ready():
    """
    Readiness probe endpoint.

    Kubernetes calls this before routing traffic to a pod.
    If it returns non-200, the pod is removed from the Service's
    endpoint list — no traffic is sent to it.
    This answers: 'Is the application ready to serve requests?'
    """
    logger.info("Readiness probe called")

    # In a real service this would check:
    # - database connectivity
    # - cache availability
    # - downstream service health
    # For this simulation we check the DB_HOST env var is set.
    if not DB_HOST:
        logger.warning("Readiness check failed — DB_HOST not configured")
        return jsonify({
            "status": "not ready",
            "reason": "database host not configured"
        }), 503

    logger.info("Readiness check passed")
    return jsonify({
        "status": "ready",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }), 200


@app.route("/audit")
def audit():
    """
    Simulated audit log endpoint.

    Returns a list of audit events — the core DataVault product.
    In production this queries the immutable audit database.
    """
    logger.info("Audit endpoint called")

    audit_entries = [
        {
            "event_id": "EVT-001",
            "timestamp": "2026-05-12T09:00:00Z",
            "actor": "james.thornton@barclays.co.uk",
            "action": "TRADE_APPROVED",
            "resource": "TRADE-GBP-4821",
            "outcome": "SUCCESS",
            "regulatory_framework": "MiFID II"
        },
        {
            "event_id": "EVT-002",
            "timestamp": "2026-05-12T09:15:00Z",
            "actor": "compliance.system@barclays.co.uk",
            "action": "CLIENT_ONBOARDING_REVIEWED",
            "resource": "CLIENT-9934",
            "outcome": "APPROVED",
            "regulatory_framework": "FCA COBS"
        },
        {
            "event_id": "EVT-003",
            "timestamp": "2026-05-12T09:32:00Z",
            "actor": "admin@barclays.co.uk",
            "action": "CONFIG_CHANGED",
            "resource": "SYSTEM-RISK-THRESHOLD",
            "outcome": "SUCCESS",
            "regulatory_framework": "FCA SYSC"
        }
    ]

    return jsonify({
        "service": "DataVault Audit Trail API",
        "version": APP_VERSION,
        "environment": ENVIRONMENT,
        "record_count": len(audit_entries),
        "entries": audit_entries
    }), 200


# ── Entry Point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    logger.info(f"Starting DataVault API v{APP_VERSION} on port {port}")
    app.run(host="0.0.0.0", port=port)
