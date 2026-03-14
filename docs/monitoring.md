# Monitoring Guide

## Health Endpoints

### Backend (Spring Boot Actuator)
```
GET https://healthcoach.duckdns.org/actuator/health
```
Returns JSON with status of all health components. Example:
```json
{
  "status": "UP",
  "components": {
    "aiService": { "status": "UP", "details": { "url": "http://fastapi-ai:8000" } },
    "db":        { "status": "UP", "details": { "database": "PostgreSQL" } },
    "diskSpace": { "status": "UP", "details": { "free": 123456789 } }
  }
}
```

### AI Service (internal only — from VM)
```
GET http://localhost:8000/health
```

### Quick healthcheck script
```bash
bash scripts/healthcheck.sh                          # checks https://healthcoach.duckdns.org
bash scripts/healthcheck.sh http://localhost:8080    # checks local dev
```

---

## GCP Uptime Check (Free Tier)

Set up a GCP uptime check to get email alerts when the backend goes down:

1. Go to **Cloud Monitoring → Uptime checks → Create**
2. Target: `https://healthcoach.duckdns.org/actuator/health`
3. Check frequency: every 5 minutes
4. Alert policy: email on failure for 1 minute

Free tier allows 1 uptime check and 1 alerting policy.

---

## Log Locations

### Backend logs (on VM)
```bash
gcloud compute ssh health-coach-dev --zone=us-central1-a \
  --command="sudo docker logs health-coach-backend --tail=100 -f"
```

### AI service logs
```bash
gcloud compute ssh health-coach-dev --zone=us-central1-a \
  --command="sudo docker logs health-coach-ai --tail=100 -f"
```

Logs are JSON-structured (one line per event):
```json
{"timestamp":"2026-03-14T12:00:00Z","level":"INFO","logger":"c.h.food.FoodController","message":"POST /api/food/logs","thread":"http-nio-8080-exec-1"}
```

---

## Alert Table

| Signal | Threshold | Action |
|--------|-----------|--------|
| `aiService` component DOWN | >1 min | Check AI container; see [runbook.md](runbook.md) |
| `db` component DOWN | >1 min | Check Postgres; see [runbook.md](runbook.md) |
| HTTP 5xx rate >5% | sustained 5 min | Check backend logs; restart if needed |
| Disk space <500 MB | — | Delete old medical uploads; expand volume |
| RabbitMQ queue depth >100 | — | Check AI consumer; restart fastapi-ai container |

---

## Cron-based Healthcheck (on VM)
```bash
# Add to crontab on the VM:
# crontab -e
*/5 * * * * /opt/health-coach/scripts/healthcheck.sh http://localhost:8080 >> /var/log/healthcheck.log 2>&1
```
