# Data Breach Notification Procedure
**Compliance:** DPDP Act 2023 (India) — Section 8(6) requires notification within 72 hours

---

## 1. Detection and Initial Assessment (0–6 hours)

### Immediate steps
1. **Isolate** — If breach is ongoing, take the affected service offline:
   ```bash
   gcloud compute ssh health-coach-dev --zone=us-central1-a \
     --command="cd /opt/health-coach && docker compose stop backend"
   ```
2. **Preserve** — Snapshot PostgreSQL before any remediation:
   ```bash
   gcloud compute ssh health-coach-dev --zone=us-central1-a \
     --command="pg_dump -U healthcoach healthcoach > /tmp/breach_snapshot_$(date +%Y%m%d_%H%M%S).sql"
   ```
3. **Assess scope** — Query affected rows:
   ```sql
   -- Who was affected and what data?
   SELECT u.id, u.email, u.created_at,
          count(mr.id) AS medical_reports,
          count(fl.id) AS food_logs
   FROM users u
   LEFT JOIN medical_reports mr ON mr.user_id = u.id
   LEFT JOIN food_logs fl ON fl.user_id = u.id
   GROUP BY u.id, u.email, u.created_at;
   ```
4. **Record** — Log the incident with timestamp, vector, and estimated scope.

---

## 2. Contain and Remediate (6–24 hours)

| Action | Command / Steps |
|--------|----------------|
| Rotate JWT secret | Update `health-coach-jwt-secret` in GCP Secret Manager → redeploy |
| Rotate DB password | Update `health-coach-db-password` in GCP Secret Manager → restart containers |
| Rotate encryption key | Generate new key: `openssl rand -base64 32` → update `health-coach-encryption-key` → **re-encrypt all medical fields** |
| Invalidate sessions | Bump JWT version claim (add `jti` blocklist or rotate secret above) |
| Patch vulnerability | Fix root cause → build new image → `docker compose up -d` on VM |

### Re-encrypting medical fields after key rotation
```bash
# Run in orchestrator container after key update
docker exec health-coach-backend java -jar \
  /app/tools/re-encrypt-medical.jar \
  --old-key=$OLD_KEY --new-key=$NEW_KEY
```
*(re-encrypt-medical.jar is a one-shot migration tool — build from `tools/ReEncryptMedical.java`)*

---

## 3. Notify (24–72 hours)

### Required under DPDP Act 2023 Section 8(6)
**Deadline: 72 hours from discovery**

#### 3a. Notify CERT-In
Submit breach report at: https://www.cert-in.org.in/incidentResponse.php

Required fields:
- Date/time of discovery
- Nature of breach (unauthorized access / data leak / ransomware)
- Categories of data involved (health data, contact info, etc.)
- Estimated number of individuals affected
- Remediation actions taken

#### 3b. Notify affected users
Send email within 72 hours:

```
Subject: Important: Security Incident Notification — Personal Health Coach

Dear [Name],

We are writing to inform you of a security incident that may have affected
your Personal Health Coach account.

What happened: [Brief factual description]
When: [Date/time range]
What data: [Specific fields affected — e.g. food logs, medical reports]
What we've done: [Remediation steps taken]
What you should do: [Change password, monitor accounts, etc.]

We sincerely apologise for this incident. If you have questions, contact:
privacy@healthcoach.duckdns.org

```

#### 3c. Internal notification chain
1. Product owner → notified within 1 hour of detection
2. Legal/compliance → notified within 4 hours
3. All affected users → notified within 72 hours

---

## 4. Post-Incident Review (72 hours+)

1. **Root cause analysis** — document in `docs/incidents/YYYY-MM-DD-incident.md`
2. **Security improvements** — file issues for any discovered vulnerabilities
3. **Consent re-collection** — if data was compromised, require re-consent from all affected users:
   ```sql
   UPDATE users SET consent_version = NULL WHERE id IN (...affected user IDs...);
   ```
4. **Regulatory follow-up** — respond to any CERT-In or Data Protection Board queries within 30 days

---

## 5. Contact Matrix

| Role | Contact | Escalation deadline |
|------|---------|-------------------|
| On-call engineer | Check PagerDuty / Slack #alerts | Immediate |
| Product owner | [owner email] | 1 hour |
| CERT-In | https://www.cert-in.org.in | 72 hours |
| Data Protection Board (India) | https://www.meity.gov.in | As required |

---

*Last updated: 2026-03-14 | Next review: 2026-09-14*
