#!/usr/bin/env bash
# deploy.sh — Build Docker images locally, push to GCR, deploy to GCP VM
#
# Usage:
#   bash scripts/deploy.sh            # build + push + deploy
#   bash scripts/deploy.sh build      # build + push only
#   bash scripts/deploy.sh deploy     # SSH deploy only (uses latest GCR images)

set -euo pipefail

PROJECT_ID="my-project-poc-478915"
REGION="us"
ZONE="us-central1-a"
VM="health-coach-dev"
GCR="gcr.io/${PROJECT_ID}"
APP_DIR="/opt/health-coach"

GREEN="\033[1;32m"; RED="\033[1;31m"; YELLOW="\033[1;33m"; RESET="\033[0m"
step() { echo -e "\n${YELLOW}▶ $1${RESET}"; }
ok()   { echo -e "${GREEN}✓ $1${RESET}"; }

MODE="${1:-all}"   # all | build | deploy

# ── 1. Build & push images ────────────────────────────────────────────────────
if [[ "$MODE" == "all" || "$MODE" == "build" ]]; then
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    step "Authenticating Docker to GCR..."
    gcloud auth configure-docker --quiet

    step "Building backend image (linux/amd64)..."
    docker buildx build \
        --platform linux/amd64 \
        --tag "${GCR}/health-coach-backend:latest" \
        --push \
        "$ROOT/services/orchestrator"
    ok "Backend image pushed to ${GCR}/health-coach-backend:latest"

    step "Building AI engine image (linux/amd64)..."
    docker buildx build \
        --platform linux/amd64 \
        --tag "${GCR}/health-coach-ai:latest" \
        --push \
        "$ROOT/services/ai-engine"
    ok "AI engine image pushed to ${GCR}/health-coach-ai:latest"
fi

# ── 2. Deploy to VM ───────────────────────────────────────────────────────────
if [[ "$MODE" == "all" || "$MODE" == "deploy" ]]; then
    step "Fetching secrets from GCP Secret Manager..."

    fetch() { gcloud secrets versions access latest --secret="$1" --project="$PROJECT_ID" 2>/dev/null; }

    JWT_SECRET=$(fetch health-coach-jwt-secret)
    DB_PASSWORD=$(fetch health-coach-db-password)
    DB_USER=$(fetch health-coach-db-user)
    DB_NAME=$(fetch health-coach-db-name)
    GEMINI_KEY=$(fetch health-coach-gemini-api-key)
    GOOGLE_ID=$(fetch health-coach-google-client-id)
    GEMINI_MODEL=$(fetch health-coach-gemini-model)
    RABBIT_USER=$(fetch health-coach-rabbitmq-user)
    RABBIT_PASS=$(fetch health-coach-rabbitmq-pass)
    ENC_KEY=$(fetch health-coach-encryption-key)

    ok "All secrets fetched"

    step "Writing prod env file to VM..."
    TMPENV=$(mktemp /tmp/.env.prod.XXXXXX)
    trap 'rm -f "$TMPENV"' EXIT

    cat > "$TMPENV" << ENVEOF
POSTGRES_DB=${DB_NAME}
POSTGRES_USER=${DB_USER}
POSTGRES_PASSWORD=${DB_PASSWORD}
SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/${DB_NAME}
SPRING_DATASOURCE_USERNAME=${DB_USER}
SPRING_DATASOURCE_PASSWORD=${DB_PASSWORD}
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRATION_MS=86400000
AI_BASE_URL=http://fastapi-ai:8000
GOOGLE_CLIENT_ID=${GOOGLE_ID}
GEMINI_API_KEY=${GEMINI_KEY}
GEMINI_MODEL=${GEMINI_MODEL}
RABBITMQ_USER=${RABBIT_USER}
RABBITMQ_PASS=${RABBIT_PASS}
REDIS_URL=redis://redis:6379
APP_ENCRYPTION_KEY=${ENC_KEY}
GCS_BUCKET_NAME=health-coach-db-backups
ENVEOF

    gcloud compute scp "$TMPENV" "${VM}:/tmp/.env.prod" \
        --project="$PROJECT_ID" --zone="$ZONE" --quiet
    rm -f "$TMPENV"
    trap - EXIT
    ok "Env file uploaded"

    step "Pulling new images and restarting services on VM..."
    gcloud compute ssh "$VM" \
        --project="$PROJECT_ID" --zone="$ZONE" --quiet \
        --command="
set -euo pipefail
cd ${APP_DIR}

# Auth docker to GCR
sudo docker-credential-gcr configure-docker --registries gcr.io 2>/dev/null || \
  sudo gcloud auth configure-docker --quiet

# Copy env file to app dir
sudo cp /tmp/.env.prod ${APP_DIR}/.env
sudo rm -f /tmp/.env.prod

# Pull new images
sudo docker pull ${GCR}/health-coach-backend:latest
sudo docker pull ${GCR}/health-coach-ai:latest

# Restart only backend + AI (postgres/rabbit/redis keep their data)
sudo docker compose -f docker-compose.prod.yml up -d --no-build springboot-app fastapi-ai
echo 'Services restarted. Spring Boot takes ~4 min to start on e2-micro.'
"
    ok "Deploy complete → https://healthcoach.duckdns.org"
    echo ""
    echo "  Monitor: bash scripts/healthcheck.sh"
    echo "  Logs:    gcloud compute ssh $VM --zone=$ZONE --command='sudo docker logs health-coach-backend -f'"
fi
