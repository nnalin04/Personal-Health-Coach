# Incident Runbook

## 1. API Outage

### Symptoms
- `/actuator/health` returns DOWN or times out
- Mobile app shows "Connection error"

### Diagnosis
```bash
# SSH to VM
gcloud compute ssh health-coach-dev --zone=us-central1-a --project=my-project-poc-478915 --quiet

# Check container status
sudo docker compose -f /opt/health-coach/docker-compose.prod.yml ps

# Check logs
sudo docker logs health-coach-backend --tail=50
sudo docker logs health-coach-ai --tail=50
```

### Recovery
```bash
# Restart all services
cd /opt/health-coach
sudo docker compose -f docker-compose.prod.yml up -d

# Restart single service
sudo docker compose -f docker-compose.prod.yml restart springboot-app
```

Spring Boot takes ~4.5 min to start on e2-micro. 502s during this window are expected.

---

## 2. Database Restore

### List available backups
```bash
gcloud storage ls gs://health-coach-db-backups/ --project=my-project-poc-478915
```

### Restore from backup
```bash
# On the VM:
BACKUP="healthcoach_20260314_020001.sql"
gsutil cp gs://health-coach-db-backups/$BACKUP /tmp/$BACKUP

# Stop backend to prevent writes
sudo docker compose -f /opt/health-coach/docker-compose.prod.yml stop springboot-app

# Restore
sudo docker exec health-coach-postgres psql -U healthcoach -d healthcoach < /tmp/$BACKUP

# Re-run Flyway to ensure migrations are current
sudo docker compose -f /opt/health-coach/docker-compose.prod.yml start springboot-app
```

---

## 3. Key Rotation

### JWT Secret
1. Generate new secret: `openssl rand -base64 48`
2. Update in GCP Secret Manager:
   ```bash
   echo -n "NEW_SECRET" | gcloud secrets versions add health-coach-jwt-secret --data-file=-
   ```
3. Redeploy backend to pick up new secret (all existing tokens are immediately invalidated):
   ```bash
   cd /opt/health-coach && sudo docker compose -f docker-compose.prod.yml up -d springboot-app
   ```

### Database Password
1. Generate: `openssl rand -base64 32`
2. Update `health-coach-db-password` in Secret Manager
3. Update the running Postgres user:
   ```bash
   sudo docker exec health-coach-postgres psql -U healthcoach -c "ALTER USER healthcoach PASSWORD 'NEW_PASSWORD';"
   ```
4. Restart backend

### Encryption Key (medical fields)
1. Generate: `openssl rand -base64 32`
2. Update `health-coach-encryption-key` in Secret Manager
3. Re-encrypt all medical fields:
   ```bash
   # Run the re-encryption migration tool
   docker exec health-coach-backend java -jar \
     /app/tools/re-encrypt-medical.jar \
     --old-key=$OLD_KEY --new-key=$NEW_KEY
   ```
4. Restart backend

---

## 4. TLS Certificate Renewal

Let's Encrypt certificates expire every 90 days. Certbot auto-renews; if it fails:

```bash
# On VM:
sudo certbot renew --nginx

# Or force renewal:
sudo certbot certonly --standalone -d healthcoach.duckdns.org --force-renewal

# Restart nginx to load new cert:
sudo docker restart health-coach-nginx
```

Current cert valid until: **2026-05-30**

---

## 5. RabbitMQ Queue Backlog

```bash
# Check queue depth
sudo docker exec health-coach-rabbitmq rabbitmqctl list_queues name messages

# If AI consumer is stuck, restart:
sudo docker compose -f /opt/health-coach/docker-compose.prod.yml restart fastapi-ai

# Purge a queue (last resort — drops unprocessed tasks):
sudo docker exec health-coach-rabbitmq rabbitmqctl purge_queue health.tasks
```

---

*See [breach_notification_procedure.md](breach_notification_procedure.md) for data breach response.*
