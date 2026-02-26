#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 5 ]]; then
  cat <<'USAGE'
Usage:
  ./deploy_to_gcp.sh <env> <project_id> <zone> <instance_name> <machine_type>

Example:
  ./deploy_to_gcp.sh dev my-project us-central1-a health-coach-dev e2-micro
USAGE
  exit 1
fi

ENVIRONMENT="$1"
PROJECT_ID="$2"
ZONE="$3"
INSTANCE_NAME="$4"
MACHINE_TYPE="$5"

case "$ENVIRONMENT" in
  dev|uat|prod) ;;
  *)
    echo "Invalid environment: $ENVIRONMENT. Use one of: dev, uat, prod"
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE=".env.${ENVIRONMENT}"
ENV_TMPL=".env.${ENVIRONMENT}.tmpl"
COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"
APP_DIR="/opt/health-coach"
TARBALL="/tmp/health-coach-${ENVIRONMENT}.tar.gz"
FIREWALL_RULE="allow-health-coach-${ENVIRONMENT}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  if [[ -f "$ENV_TMPL" ]]; then
    echo "Create it from template:"
    echo "  cp $ENV_TMPL $ENV_FILE"
  fi
  exit 1
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Missing $COMPOSE_FILE"
  exit 1
fi

required_keys=(
  POSTGRES_DB
  POSTGRES_USER
  POSTGRES_PASSWORD
  SPRING_DATASOURCE_URL
  SPRING_DATASOURCE_USERNAME
  SPRING_DATASOURCE_PASSWORD
  JWT_SECRET
  JWT_EXPIRATION_MS
  GOOGLE_CLIENT_ID
  GEMINI_API_KEY
  GEMINI_MODEL
)

for key in "${required_keys[@]}"; do
  if ! grep -q "^${key}=" "$ENV_FILE"; then
    echo "Missing required key in $ENV_FILE: $key"
    exit 1
  fi
done

if grep -Eq '=(your_|generate_)' "$ENV_FILE"; then
  echo "Detected placeholder values in $ENV_FILE. Replace all template placeholders before deploy."
  exit 1
fi

echo "Deploying environment=$ENVIRONMENT to project=$PROJECT_ID zone=$ZONE instance=$INSTANCE_NAME"
gcloud config set project "$PROJECT_ID" >/dev/null

echo "Enabling required APIs..."
gcloud services enable compute.googleapis.com >/dev/null

echo "Ensuring firewall rule exists..."
gcloud compute firewall-rules create "$FIREWALL_RULE" \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:22,tcp:8080 \
  --source-ranges=0.0.0.0/0 \
  --target-tags="$INSTANCE_NAME" >/dev/null 2>&1 || true

if gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" >/dev/null 2>&1; then
  echo "Instance already exists: $INSTANCE_NAME"
else
  echo "Creating instance: $INSTANCE_NAME"
  gcloud compute instances create "$INSTANCE_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --image-family="cos-stable" \
    --image-project="cos-cloud" \
    --tags="$INSTANCE_NAME" \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --metadata=startup-script='#!/bin/bash
set -eux
mkdir -p /opt/health-coach
mkdir -p /root/.docker/cli-plugins || true
if ! docker compose version >/dev/null 2>&1; then
  COMPOSE_VERSION="v2.29.7"
  COMPOSE_BIN="/root/.docker/cli-plugins/docker-compose"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" -o "${COMPOSE_BIN}"
  else
    wget -q "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" -O "${COMPOSE_BIN}"
  fi
  chmod +x "${COMPOSE_BIN}"
fi
'
fi

echo "Waiting for SSH..."
sleep 20

echo "Packaging source..."
tar czf "$TARBALL" \
  --exclude='.git' \
  --exclude='backend/target' \
  --exclude='ai-service/.venv' \
  --exclude='ai-service/__pycache__' \
  --exclude='ai-service/app/**/__pycache__' \
  --exclude='mobile' \
  "$COMPOSE_FILE" "$ENV_FILE" backend ai-service

echo "Uploading package..."
gcloud compute scp --zone="$ZONE" "$TARBALL" "$INSTANCE_NAME:~/health-coach.tar.gz"

echo "Deploying on VM..."
gcloud compute ssh --zone="$ZONE" "$INSTANCE_NAME" --command="
set -euo pipefail
sudo mkdir -p $APP_DIR
sudo tar xzf ~/health-coach.tar.gz -C $APP_DIR
cd $APP_DIR
sudo mv '$ENV_FILE' .env
sudo mv '$COMPOSE_FILE' docker-compose.yml
sudo docker compose down --remove-orphans || true
sudo docker compose up -d --build
"

PUBLIC_IP="$(gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')"
echo "Deployment complete for $ENVIRONMENT"
echo "Backend URL: http://${PUBLIC_IP}:8080"
echo "Health check: http://${PUBLIC_IP}:8080/actuator/health"
