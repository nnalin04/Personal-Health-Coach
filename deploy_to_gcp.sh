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
if [[ ! -f "$ENV_FILE" ]]; then
  ENV_FILE="env.${ENVIRONMENT}"
fi
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

# Determine region from zone (e.g., us-central1-a -> us-central1)
REGION="${ZONE%-*}"
IP_NAME="${INSTANCE_NAME}-ip"

echo "Ensuring static IP exists..."
if ! gcloud compute addresses describe "$IP_NAME" --project "$PROJECT_ID" --region="$REGION" >/dev/null 2>&1; then
  echo "Creating static IP: $IP_NAME"
  gcloud compute addresses create "$IP_NAME" --project "$PROJECT_ID" --region="$REGION" >/dev/null
fi
STATIC_IP=$(gcloud compute addresses describe "$IP_NAME" --project "$PROJECT_ID" --region="$REGION" --format='get(address)')
echo "Using Static IP: $STATIC_IP"

echo "Checking for service account..."
# Attempt to find the default compute service account or any available one
SA_EMAIL=$(gcloud iam service-accounts list --project "$PROJECT_ID" --filter="email ~ compute@developer.gserviceaccount.com" --format='get(email)' --limit=1 2>/dev/null || true)
if [[ -z "$SA_EMAIL" ]]; then
  SA_EMAIL=$(gcloud iam service-accounts list --project "$PROJECT_ID" --format='get(email)' --limit=1 2>/dev/null || true)
fi

SA_FLAG=""
if [[ -n "$SA_EMAIL" ]]; then
  echo "Using service account: $SA_EMAIL"
  SA_FLAG="--service-account=$SA_EMAIL"
else
  echo "WARNING: No service account found. This may cause issues with instance metadata access."
  SA_FLAG="--no-service-account"
fi

echo "Enabling required APIs..."
gcloud services enable compute.googleapis.com --project "$PROJECT_ID" >/dev/null

echo "Ensuring firewall rule exists (HTTP, HTTPS, SSH, and backend)..."
# Try to update existing rule first; if it doesn't exist, create it
if gcloud compute firewall-rules describe "$FIREWALL_RULE" --project "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud compute firewall-rules update "$FIREWALL_RULE" \
    --project "$PROJECT_ID" \
    --rules=tcp:22,tcp:80,tcp:443,tcp:8080 >/dev/null 2>&1 || true
else
  gcloud compute firewall-rules create "$FIREWALL_RULE" \
    --project "$PROJECT_ID" \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:22,tcp:80,tcp:443,tcp:8080 \
    --source-ranges=0.0.0.0/0 \
    --target-tags="$INSTANCE_NAME" >/dev/null 2>&1 || true
fi

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

echo "Packaging source..."
# Use --no-xattrs and COPYFILE_DISABLE to avoid Mac metadata warnings
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
  "$COMPOSE_FILE" "$ENV_FILE" backend ai-service nginx

echo "Uploading package..."
gcloud compute scp --project "$PROJECT_ID" --zone="$ZONE" "$TARBALL" "$INSTANCE_NAME:~/health-coach.tar.gz"

echo "Deploying on VM..."
gcloud compute ssh --project "$PROJECT_ID" --zone="$ZONE" "$INSTANCE_NAME" --command="
set -euo pipefail
sudo mkdir -p $APP_DIR

# Install Docker and Compose if missing (Ubuntu specific)
if ! command -v docker-compose >/dev/null 2>&1; then
  echo 'Installing Docker and Docker Compose...'
  sudo apt-get update
  sudo apt-get install -y docker.io docker-compose
  sudo systemctl enable --now docker
fi

sudo tar xzf ~/health-coach.tar.gz -C $APP_DIR
cd $APP_DIR
sudo mv '$ENV_FILE' .env
sudo mv '$COMPOSE_FILE' docker-compose.yml

# Use standard docker-compose
sudo docker-compose down --remove-orphans || true
sudo docker-compose up -d --build
"

PUBLIC_IP="$(gcloud compute instances describe "$INSTANCE_NAME" --project "$PROJECT_ID" --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')"
echo "Deployment complete for $ENVIRONMENT"
echo ""
echo "  HTTP URL:     http://${PUBLIC_IP}"
echo "  Health check: http://${PUBLIC_IP}/actuator/health"
echo ""
# NOTE: Port 8080 is no longer exposed directly to the host.
# nginx (port 80) now proxies all traffic to springboot-app:8080 internally.
#
# To enable full HTTPS once a domain is available:
#   1. Point your domain A record to ${PUBLIC_IP}
#   2. Update nginx/nginx.conf: set server_name, uncomment HTTPS server block,
#      replace YOUR_DOMAIN_HERE, enable the 301 redirect in the HTTP block.
#   3. Update the certbot command in docker-compose.prod.yml with your domain.
#   4. Re-run this deploy script, then on the VM run:
#        docker-compose -f /opt/health-coach/docker-compose.yml run --rm certbot
#   5. See docs/HTTPS_SETUP.md for the full step-by-step guide.
