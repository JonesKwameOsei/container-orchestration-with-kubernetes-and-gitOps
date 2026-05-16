# syntax=docker/dockerfile:1
# ── Stage 1: Builder ──────────────────────────────────────────────────────────
# Install dependencies in a separate stage so they don't bloat the final image.
# The builder has pip and build tools. The final image does not.

ARG PYTHON_VERSION=3.13.12
FROM python:${PYTHON_VERSION}-slim AS builder

# Prevents Python from writing pyc files.
ENV PYTHONDONTWRITEBYTECODE=1

# Keeps Python from buffering stdout and stderr to avoid situations where
# the application crashes without emitting any logs due to buffering.
ENV PYTHONUNBUFFERED=1

WORKDIR /build

# Copy only requirements first — Docker layer caching means this layer
# is only rebuilt when requirements.txt changes, not on every code change.
COPY requirements.txt .

RUN pip install --upgrade pip \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
# Start from a clean slim image. Copy only what's needed to run the app.
# No pip, no build tools, no cache — smaller attack surface.
FROM python:${PYTHON_VERSION}-slim AS runtime

# Patch OS-level CVEs — Trivy blocks CRITICAL vulnerabilities
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Security: run as non-root user.
# If the container is compromised, the attacker has no root privileges.
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser

WORKDIR /app

# Copy installed packeages from builder stage
COPY --from=builder /install /usr/local

# Copy app code
COPY main.py .

USER appuser

EXPOSE 5000
# Health check built into the image.
# Docker and Kubernetes can both use this.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "60", "--access-logfile", "-", "main:app"]
