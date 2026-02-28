#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-my-project-poc-478915}"
ZONE="${ZONE:-us-central1-a}"
INSTANCE_NAME="${INSTANCE_NAME:-health-coach-prod}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-standard-2}"
ENVIRONMENT="prod"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"
APP_DIR="/opt/health-coach"
TARBALL="/tmp/health-coach-${ENVIRONMENT}.tar.gz"
FIREWALL_RULE="allow-health-coach-${ENVIRONMENT}"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Missing $COMPOSE_FILE"
  exit 1
fi

# ---------------------------------------------------------------------------
# Fetch secrets from GCP Secret Manager
# ---------------------------------------------------------------------------
echo "Fetching secrets from GCP Secret Manager..."

fetch_secret() {
  local secret_name="$1"
  local value
  value=$(gcloud secrets versions access latest \
    --secret="$secret_name" \
    --project="$PROJECT_ID" 2>/dev/null) || {
    echo "ERROR: Failed to fetch secret '$secret_name' from Secret Manager." >&2
    exit 1
  }
  printf '%s' "$value"
}

JWT_SECRET=$(fetch_secret "health-coach-jwt-secret")
DB_PASSWORD=$(fetch_secret "health-coach-db-password")
DB_USER=$(fetch_secret "health-coach-db-user")
DB_NAME=$(fetch_secret "health-coach-db-name")
GEMINI_KEY=$(fetch_secret "health-coach-gemini-api-key")
GOOGLE_ID=$(fetch_secret "health-coach-google-client-id")
GEMINI_MODEL=$(fetch_secret "health-coach-gemini-model")

echo "All secrets fetched successfully."

# ---------------------------------------------------------------------------
# Write a temporary .env file (never persisted to disk long-term)
# ---------------------------------------------------------------------------
TMPENV=$(mktemp /tmp/.env.prod.XXXXXX)
trap 'rm -f "$TMPENV"' EXIT

cat > "$TMPENV" << EOF
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
EOF

echo "Temporary env file written."

# ---------------------------------------------------------------------------
# Infrastructure: static IP, firewall, VM
# ---------------------------------------------------------------------------
REGION="${ZONE%-*}"
IP_NAME="${INSTANCE_NAME}-ip"

echo "Deploying environment=${ENVIRONMENT} to project=${PROJECT_ID} zone=${ZONE} instance=${INSTANCE_NAME}"

echo "Enabling required APIs..."
gcloud services enable compute.googleapis.com --project "$PROJECT_ID" >/dev/null

echo "Ensuring static IP exists..."
if ! gcloud compute addresses describe "$IP_NAME" --project "$PROJECT_ID" --region="$REGION" >/dev/null 2>&1; then
  echo "Creating static IP: $IP_NAME"
  gcloud compute addresses create "$IP_NAME" --project "$PROJECT_ID" --region="$REGION" >/dev/null
fi
STATIC_IP=$(gcloud compute addresses describe "$IP_NAME" --project "$PROJECT_ID" --region="$REGION" --format='get(address)')
echo "Using Static IP: $STATIC_IP"

echo "Checking for service account..."
SA_EMAIL=$(gcloud iam service-accounts list --project "$PROJECT_ID" \
  --filter="email ~ compute@developer.gserviceaccount.com" \
  --format='get(email)' --limit=1 2>/dev/null || true)
if [[ -z "$SA_EMAIL" ]]; then
  SA_EMAIL=$(gcloud iam service-accounts list --project "$PROJECT_ID" \
    --format='get(email)' --limit=1 2>/dev/null || true)
fi

SA_FLAG=""
if [[ -n "$SA_EMAIL" ]]; then
  echo "Using service account: $SA_EMAIL"
  SA_FLAG="--service-account=$SA_EMAIL"
else
  echo "WARNING: No service account found. This may cause issues with instance metadata access."
  SA_FLAG="--no-service-account"
fi

echo "Ensuring firewall rule exists..."
gcloud compute firewall-rules create "$FIREWALL_RULE" \
  --project "$PROJECT_ID" \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:22,tcp:8080 \
  --source-ranges=0.0.0.0/0 \
  --target-tags="$INSTANCE_NAME" >/dev/null 2>&1 || true

if gcloud compute instances describe "$INSTANCE_NAME" --project "$PROJECT_ID" --zone="$ZONE" >/dev/null 2>&1; then
  echo "Instance already exists: $INSTANCE_NAME"
else
  echo "Creating instance (Ubuntu 22.04 LTS): $INSTANCE_NAME"
  gcloud compute instances create "$INSTANCE_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --image-family="ubuntu-2204-lts" \
    --image-project="ubuntu-os-cloud" \
    --tags="$INSTANCE_NAME" \
    --address="$STATIC_IP" \
    $SA_FLAG \
    --scopes=https://www.googleapis.com/auth/cloud-platform
fi

echo "Waiting for SSH..."
sleep 20

# ---------------------------------------------------------------------------
# Upload secrets env file, then immediately delete local copy
# ---------------------------------------------------------------------------
echo "Uploading env file to VM..."
gcloud compute scp "$TMPENV" "${INSTANCE_NAME}:/tmp/.env" \
  --project "$PROJECT_ID" --zone="$ZONE"
rm -f "$TMPENV"
trap - EXIT
echo "Local temp env file deleted."

# ---------------------------------------------------------------------------
# Package and upload source
# ---------------------------------------------------------------------------
echo "Packaging source..."
TAR_OPTS="czf"
export COPYFILE_DISABLE=1
if tar --version | grep -q "gnu"; then
  TAR_OPTS="--no-xattrs -czf"
fi

tar $TAR_OPTS "$TARBALL" \
  --exclude='.git' \
  --exclude='backend/target' \
  --exclude='ai-service/.venv' \
  --exclude='ai-service/__pycache__' \
  --exclude='ai-service/app/**/__pycache__' \
  --exclude='mobile' \
  --exclude='._*' \
  "$COMPOSE_FILE" backend ai-service

echo "Uploading package..."
gcloud compute scp --project "$PROJECT_ID" --zone="$ZONE" \
  "$TARBALL" "${INSTANCE_NAME}:~/health-coach.tar.gz"

# ---------------------------------------------------------------------------
# Deploy on VM
# ---------------------------------------------------------------------------
echo "Deploying on VM..."
gcloud compute ssh --project "$PROJECT_ID" --zone="$ZONE" "$INSTANCE_NAME" --command="
set -euo pipefail
sudo mkdir -p $APP_DIR

if ! command -v docker-compose >/dev/null 2>&1; then
  echo 'Installing Docker and Docker Compose...'
  sudo apt-get update
  sudo apt-get install -y docker.io docker-compose
  sudo systemctl enable --now docker
fi

sudo tar xzf ~/health-coach.tar.gz -C $APP_DIR
cd $APP_DIR
sudo mv /tmp/.env .env
sudo mv '$COMPOSE_FILE' docker-compose.yml

sudo docker-compose down --remove-orphans || true
sudo docker-compose up -d --build
"

PUBLIC_IP="\$(gcloud compute instances describe "$INSTANCE_NAME" --project "$PROJECT_ID" --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')"
echo "Deployment complete for $ENVIRONMENT"
echo "Backend URL: http://${PUBLIC_IP}:8080"
echo "Health check: http://${PUBLIC_IP}:8080/actuator/health"
