# Monitoring Guide — Personal Health Coach

## Service Health Endpoints

| Service | Endpoint | Auth |
|---------|----------|------|
| Backend (Spring Boot) | `GET /actuator/health` | None (public) |
| AI Service (FastAPI) | `GET /health` | None (internal only) |

### Backend Health Response
`GET https://healthcoach.duckdns.org/actuator/health`

```json
{
  "status": "UP",
  "components": {
    "aiService": { "status": "UP", "details": { "url": "http://fastapi-ai:8000" } },
    "db":        { "status": "UP", "details": { "database": "PostgreSQL" } },
    "diskSpace": { "status": "UP", "details": { "total": ..., "free": ..., "threshold": ... } }
  }
}
```

- `status: DOWN` on any component → investigate that component first.
- `aiService: DOWN` → FastAPI container may have crashed; check `docker compose logs fastapi-ai`.
- `db: DOWN` → Postgres unhealthy; check `docker compose logs postgres`.

---

## Local Health Check Script

```bash
bash scripts/healthcheck.sh
# Override URLs:
BACKEND_URL=http://localhost:8080 AI_URL=http://localhost:8000 bash scripts/healthcheck.sh
```

---

## GCP Uptime Check (Free Tier)

1. Go to **GCP Console → Monitoring → Uptime checks → Create check**
2. **Target:** HTTPS, `healthcoach.duckdns.org`, path `/actuator/health`, port 443
3. **Check frequency:** Every 5 minutes
4. **Alert policy:** Create alert on check failure → notify via email or PagerDuty

Cost: **Free** (GCP uptime checks are free tier; up to 1M API calls/month).

---

## VM Cron Health Check

To run the healthcheck on the VM every 5 minutes and email on failure:

```bash
# SSH to VM:
ssh -i ~/.ssh/health_coach_key ubuntu@34.45.115.228

# Add cron entry:
crontab -e
# Add line:
*/5 * * * * BACKEND_URL=https://healthcoach.duckdns.org bash /opt/health-coach/scripts/healthcheck.sh >> /var/log/healthcheck.log 2>&1 || echo "ALERT: health check failed at $(date)" | mail -s "Health Coach DOWN" admin@example.com
```

---

## Key Logs

| Service | Log Location (prod) | Command |
|---------|---------------------|---------|
| Backend | `/app/logs/backend.log` (JSON) | `docker exec health-coach-backend tail -f /app/logs/backend.log \| jq .` |
| AI Service | stdout (JSON) | `docker compose logs -f fastapi-ai` |
| nginx | stdout | `docker compose logs -f nginx` |
| Postgres | stdout | `docker compose logs -f postgres` |

---

## Alerts to Watch

| Signal | Likely Cause | Action |
|--------|-------------|--------|
| `aiService: DOWN` in `/actuator/health` | FastAPI OOM or crash | `docker compose restart fastapi-ai` |
| `db: DOWN` | Postgres crash or disk full | Check disk, `docker compose restart postgres` |
| `diskSpace` free < 1 GB | Log or upload accumulation | Clear old logs, run `scripts/cleanup_uploads.sh` |
| 5xx spike in nginx logs | Backend exception | Check `docker compose logs springboot-app` |
