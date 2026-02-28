# Enabling HTTPS on Production

## Prerequisites
1. A domain name with an A record pointing to `34.45.115.228`
2. The server is already running with nginx on port 80

## Steps

### 1. Update nginx.conf
In `nginx/nginx.conf`:
- Set `server_name` to your domain
- In the HTTPS server block, replace `YOUR_DOMAIN_HERE` with your domain
- Uncomment the HTTPS server block entirely
- Change the HTTP server block to redirect to HTTPS (uncomment the `return 301` line and remove the `location /` proxy block)

### 2. Update docker-compose.prod.yml
In the certbot service command, replace `YOUR_DOMAIN_HERE` with your actual domain.

### 3. Run certbot to obtain the certificate
```bash
# On the GCP VM after deploying:
docker-compose -f docker-compose.prod.yml run --rm certbot
```

### 4. Set up auto-renewal
```bash
# Add to crontab on the VM:
0 12 * * * /usr/bin/docker-compose -f /opt/health-coach/docker-compose.prod.yml run --rm certbot renew --quiet && docker-compose -f /opt/health-coach/docker-compose.prod.yml restart nginx
```

### 5. Redeploy
```bash
./deploy_to_gcp_prod.sh
```
