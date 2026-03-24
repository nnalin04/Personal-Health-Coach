#!/usr/bin/env bash
# Deploy Personal Health Coach to Oracle Cloud ARM VM
#
# Run from your LOCAL machine:
#   bash infra/scripts/deploy-oracle.sh
#
# What this script does:
#   1. SSHs into Oracle VM (80.225.223.142)
#   2. Cleans up reclaimable Docker data
#   3. Clones / pulls latest code
#   4. Sets up .env.oracle from your input
#   5. Opens firewall ports 80 + 443 (Oracle iptables)
#   6. Issues Let's Encrypt TLS cert via certbot (standalone)
#   7. Builds all images on the VM (24 GB RAM — no OOM risk)
#   8. Starts all services via docker-compose.oracle.yml
#   9. Updates DuckDNS to point to Oracle IP
#
# Requirements (local):
#   - SSH key at ~/.ssh/oracle_vm.key
#   - git repo pushed to origin (script pulls latest on VM)
#   - .env.oracle file in project root (copy from .env.oracle.example and fill)

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
ORACLE_IP="80.225.223.142"
ORACLE_USER="ubuntu"
SSH_KEY="$HOME/.ssh/oracle_vm.key"
REPO_URL="$(git -C "$(dirname "$0")/../.." remote get-url origin 2>/dev/null || echo '')"
REMOTE_DIR="/home/ubuntu/personal-health-coach"
DOMAIN="healthcoach.duckdns.org"
LOCAL_ENV="$(dirname "$0")/../../.env.oracle"

# ── Colour helpers ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠ $*${NC}"; }
die()  { echo -e "${RED}✗ $*${NC}"; exit 1; }

ssh_run() { ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "${ORACLE_USER}@${ORACLE_IP}" "$@"; }

# ── Preflight ─────────────────────────────────────────────────────────────────
echo ""
echo "Personal Health Coach — Oracle Deploy"
echo "======================================"

[ -f "$SSH_KEY" ] || die "SSH key not found at $SSH_KEY"

if [ ! -f "$LOCAL_ENV" ]; then
    die ".env.oracle not found at $(realpath "$LOCAL_ENV" 2>/dev/null || echo "$LOCAL_ENV")
    Copy .env.oracle.example → .env.oracle and fill in secrets, then re-run."
fi

ok "SSH key found"
ok ".env.oracle found"

# ── 1. Clean Docker cache on VM ───────────────────────────────────────────────
echo ""
echo "→ Cleaning reclaimable Docker data on VM (~4 GB)..."
ssh_run "docker system prune -f --volumes 2>/dev/null || true"
ok "Docker cache cleaned"

# ── 2. Clone / pull repo on VM ────────────────────────────────────────────────
echo ""
echo "→ Syncing code on VM..."
if [ -z "$REPO_URL" ]; then
    warn "Could not detect git remote — make sure you pushed your latest code"
    warn "and that $REMOTE_DIR already exists on the VM"
else
    ssh_run "
        if [ -d '$REMOTE_DIR/.git' ]; then
            git -C '$REMOTE_DIR' pull origin main
        else
            git clone '$REPO_URL' '$REMOTE_DIR'
        fi
    "
    ok "Code synced: $REMOTE_DIR"
fi

# ── 3. Upload .env.oracle ──────────────────────────────────────────────────────
echo ""
echo "→ Uploading .env.oracle to VM..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    "$LOCAL_ENV" "${ORACLE_USER}@${ORACLE_IP}:${REMOTE_DIR}/.env.oracle"
ok ".env.oracle uploaded"

# ── 4. Open ports 80 + 443 in Oracle iptables ────────────────────────────────
echo ""
echo "→ Opening ports 80 and 443..."
ssh_run "
    sudo iptables -C INPUT -p tcp --dport 80  -j ACCEPT 2>/dev/null || sudo iptables -I INPUT 6 -p tcp --dport 80  -j ACCEPT
    sudo iptables -C INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || sudo iptables -I INPUT 6 -p tcp --dport 443 -j ACCEPT
    sudo netfilter-persistent save 2>/dev/null || true
"
ok "Ports 80 and 443 open"
warn "Also open TCP 80 + 443 in Oracle Console → VCN → Security List if not already done"

# ── 5. Issue TLS cert (certbot standalone) ────────────────────────────────────
echo ""
echo "→ Issuing Let's Encrypt certificate for $DOMAIN..."
ssh_run "
    # Install certbot if missing
    if ! command -v certbot &>/dev/null; then
        sudo snap install --classic certbot
        sudo ln -sf /snap/bin/certbot /usr/bin/certbot
    fi

    # Stop anything on port 80 temporarily (nginx not started yet)
    docker stop health-coach-nginx 2>/dev/null || true

    # Issue cert
    if [ ! -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem ]; then
        sudo certbot certonly --standalone \
            --non-interactive --agree-tos \
            --email admin@$DOMAIN \
            -d $DOMAIN
        echo 'Certificate issued'
    else
        sudo certbot renew --quiet
        echo 'Certificate already exists — renewed if needed'
    fi
"
ok "TLS certificate ready"

# ── 6. Copy certs into Docker-managed volume ──────────────────────────────────
echo ""
echo "→ Mounting certs into Docker volume..."
ssh_run "
    # Create letsencrypt volume if not exists
    docker volume create health-coach_letsencrypt 2>/dev/null || true

    # Use a temp container to copy certs into the volume
    docker run --rm \
        -v /etc/letsencrypt:/src:ro \
        -v health-coach_letsencrypt:/dest \
        alpine sh -c 'cp -a /src/. /dest/'
"
ok "Certs copied into Docker volume"

# ── 7. Build and start all services ───────────────────────────────────────────
echo ""
echo "→ Building images on VM (this takes ~5 min for Spring Boot)..."
ssh_run "
    cd '$REMOTE_DIR'
    docker compose -f docker-compose.oracle.yml --env-file .env.oracle \
        build --no-cache 2>&1 | tail -20
"
ok "Images built"

echo ""
echo "→ Starting all services..."
ssh_run "
    cd '$REMOTE_DIR'
    docker compose -f docker-compose.oracle.yml --env-file .env.oracle \
        up -d
"
ok "Services started"

# ── 8. Update DuckDNS ────────────────────────────────────────────────────────
echo ""
DUCKDNS_TOKEN=""
if grep -q "DUCKDNS_TOKEN=" "$LOCAL_ENV" 2>/dev/null; then
    DUCKDNS_TOKEN=$(grep "^DUCKDNS_TOKEN=" "$LOCAL_ENV" | cut -d= -f2)
fi

if [ -n "$DUCKDNS_TOKEN" ]; then
    echo "→ Updating DuckDNS to point to Oracle ($ORACLE_IP)..."
    RESULT=$(curl -s "https://www.duckdns.org/update?domains=healthcoach&token=${DUCKDNS_TOKEN}&ip=${ORACLE_IP}")
    if [ "$RESULT" = "OK" ]; then
        ok "DuckDNS updated: healthcoach.duckdns.org → $ORACLE_IP"
    else
        warn "DuckDNS update returned: $RESULT — update manually at duckdns.org"
    fi
else
    warn "DUCKDNS_TOKEN not in .env.oracle — update DuckDNS manually:"
    warn "  https://www.duckdns.org/update?domains=healthcoach&token=YOUR_TOKEN&ip=$ORACLE_IP"
fi

# ── 9. Health check ───────────────────────────────────────────────────────────
echo ""
echo "→ Waiting 30s for Spring Boot to start (~4 min total, checking early)..."
sleep 30
HTTP=$(ssh_run "curl -s -o /dev/null -w '%{http_code}' http://localhost:80/api/health || echo 000")
if [ "$HTTP" = "200" ]; then
    ok "Health check passed (HTTP 200)"
else
    warn "Health check returned HTTP $HTTP — Spring Boot may still be starting (normal, ~4 min)"
    warn "Check logs: ssh -i $SSH_KEY $ORACLE_USER@$ORACLE_IP 'docker compose -f $REMOTE_DIR/docker-compose.oracle.yml logs -f springboot-app'"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "======================================"
echo "Deploy complete"
echo ""
echo "  App URL  : https://$DOMAIN"
echo "  Oracle   : $ORACLE_IP"
echo ""
echo "Useful commands (run on VM):"
echo "  docker compose -f $REMOTE_DIR/docker-compose.oracle.yml logs -f"
echo "  docker compose -f $REMOTE_DIR/docker-compose.oracle.yml ps"
echo "  docker compose -f $REMOTE_DIR/docker-compose.oracle.yml restart springboot-app"
echo ""
echo "SSH access:"
echo "  ssh -i $SSH_KEY $ORACLE_USER@$ORACLE_IP"
echo "======================================"
