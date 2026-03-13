# Incident Runbook — Personal Health Coach

**VM:** `34.45.115.228` | **Domain:** `healthcoach.duckdns.org` | **GCP Project:** `my-project-poc-478915`

---

## 1. API Outage

**Symptom:** `/actuator/health` returns non-200 or is unreachable; users get 502/504.

### Triage Steps

```bash
# 1. SSH into VM
ssh -i ~/.ssh/health_coach_key ubuntu@34.45.115.228

# 2. Check container status
cd /opt/health-coach
docker compose -f docker-compose.prod.yml ps

# 3. Check which service is down
docker compose -f docker-compose.prod.yml logs --tail=50 springboot-app
docker compose -f docker-compose.prod.yml logs --tail=50 fastapi-ai
docker compose -f docker-compose.prod.yml logs --tail=50 postgres
docker compose -f docker-compose.prod.yml logs --tail=50 nginx
```

### Recovery

```bash
# Restart a specific crashed service
docker compose -f docker-compose.prod.yml restart springboot-app
docker compose -f docker-compose.prod.yml restart fastapi-ai

# Full restart (all services)
docker compose -f docker-compose.prod.yml up -d

# Verify health
curl -s https://healthcoach.duckdns.org/actuator/health | jq .status
```

### If Backend OOM-killed (e2-micro memory pressure)
```bash
# Check memory
free -h
docker stats --no-stream

# Reduce JVM heap if needed (add to docker-compose.prod.yml environment):
# JAVA_OPTS: "-Xmx256m -Xms128m"
docker compose -f docker-compose.prod.yml up -d springboot-app
```

---

## 2. Database Restore

**Symptom:** Postgres data lost or corrupted; `db: DOWN` in health check.

### List Available Backups

```bash
gsutil ls gs://health-coach-db-backups/
# Example output:
# gs://health-coach-db-backups/health_coach_20260305_020000.sql.gz
```

### Restore Procedure

```bash
# 1. SSH to VM
ssh -i ~/.ssh/health_coach_key ubuntu@34.45.115.228
cd /opt/health-coach

# 2. Stop backend and AI service (keep postgres running)
docker compose -f docker-compose.prod.yml stop springboot-app fastapi-ai

# 3. Download the backup
BACKUP_FILE="health_coach_20260305_020000.sql.gz"   # replace with target date
gsutil cp gs://health-coach-db-backups/$BACKUP_FILE /tmp/

# 4. Restore into postgres container
gunzip -c /tmp/$BACKUP_FILE | docker exec -i health-coach-postgres \
    psql -U $POSTGRES_USER -d $POSTGRES_DB

# 5. Restart all services
docker compose -f docker-compose.prod.yml up -d

# 6. Verify via health check
curl -s https://healthcoach.duckdns.org/actuator/health | jq .components.db
```

### If Postgres Container Won't Start
```bash
# Check disk space (most common cause)
df -h

# Remove old Docker build cache if disk full
docker system prune -f

# Restart postgres
docker compose -f docker-compose.prod.yml up -d postgres
```

---

## 3. Key Rotation

**Trigger:** Security incident, suspected leak, or routine 90-day rotation.

### JWT Secret Rotation

```bash
# 1. Generate new secret (min 32 chars)
openssl rand -base64 48

# 2. Update GCP Secret Manager
gcloud secrets versions add health-coach-jwt-secret \
    --project=my-project-poc-478915 \
    --data-file=<(echo -n "NEW_SECRET_HERE")

# 3. SSH to VM and update .env
ssh -i ~/.ssh/health_coach_key ubuntu@34.45.115.228
cd /opt/health-coach
# Edit .env: update JWT_SECRET=NEW_SECRET_HERE

# 4. Restart backend (all existing tokens are now invalid — users re-login)
docker compose -f docker-compose.prod.yml restart springboot-app
```

> **Note:** Rotating JWT_SECRET invalidates ALL active sessions. Users will be logged out and must re-authenticate.

### Gemini API Key Rotation

```bash
# 1. Generate new key at https://aistudio.google.com/app/apikey
# 2. Update Secret Manager
gcloud secrets versions add health-coach-gemini-api-key \
    --project=my-project-poc-478915 \
    --data-file=<(echo -n "NEW_KEY_HERE")

# 3. Update VM .env and restart AI service
ssh -i ~/.ssh/health_coach_key ubuntu@34.45.115.228
cd /opt/health-coach
# Edit .env: update GEMINI_API_KEY=NEW_KEY_HERE
docker compose -f docker-compose.prod.yml restart fastapi-ai
```

### Database Password Rotation

```bash
# 1. Update Secret Manager
gcloud secrets versions add health-coach-db-password \
    --project=my-project-poc-478915 \
    --data-file=<(echo -n "NEW_PASSWORD_HERE")

# 2. Update postgres user password
docker exec -it health-coach-postgres \
    psql -U postgres -c "ALTER USER $POSTGRES_USER PASSWORD 'NEW_PASSWORD_HERE';"

# 3. Update VM .env (POSTGRES_PASSWORD + SPRING_DATASOURCE_PASSWORD)
# 4. Restart backend
docker compose -f docker-compose.prod.yml restart springboot-app
```

---

## 4. TLS Certificate Renewal

Let's Encrypt certificates expire every 90 days (current expiry: 2026-05-30).

```bash
# Manual renewal
ssh -i ~/.ssh/health_coach_key ubuntu@34.45.115.228
cd /opt/health-coach
docker compose -f docker-compose.prod.yml run --rm certbot renew
docker compose -f docker-compose.prod.yml restart nginx

# Verify new expiry
echo | openssl s_client -connect healthcoach.duckdns.org:443 2>/dev/null | \
    openssl x509 -noout -dates
```

---

## 5. Quick Reference

| Task | Command |
|------|---------|
| Check all container status | `docker compose -f docker-compose.prod.yml ps` |
| Tail backend logs | `docker compose -f docker-compose.prod.yml logs -f springboot-app` |
| Tail AI logs | `docker compose -f docker-compose.prod.yml logs -f fastapi-ai` |
| Run health check script | `bash scripts/healthcheck.sh` |
| List GCS backups | `gsutil ls gs://health-coach-db-backups/` |
| Check disk on VM | `df -h` |
| Check VM memory | `free -h && docker stats --no-stream` |
