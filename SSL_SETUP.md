# SSL Certificate Management with Docker

## Problem

When running `sudo certbot renew` on the host machine, certbot can't properly serve challenge files to nginx running in Docker because they're in different filesystems.

## Solution

Use the dockerized certbot service defined in `docker-compose.prod.yml` instead of the host's certbot installation.

## Initial Certificate Setup

If you need to obtain certificates for the first time:

1. **Update the email in the script:**
   ```bash
   nano scripts/obtain-ssl.sh
   # Change: EMAIL="your-email@example.com"
   ```

2. **Make sure nginx is running:**
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d nginx
   ```

3. **Run the certificate obtainment script:**
   ```bash
   ./scripts/obtain-ssl.sh
   ```

## Certificate Renewal

To renew certificates (do this every 60-90 days, or set up a cron job):

```bash
./scripts/renew-ssl.sh
```

## Automatic Renewal with Cron

Add this to your crontab (run `crontab -e` on the server):

```bash
# Renew SSL certificates at 3 AM on the 1st of every month
0 3 1 * * cd /root/mymoney && ./scripts/renew-ssl.sh >> /var/log/certbot-renew.log 2>&1
```

## Manual Renewal (Alternative)

If you prefer to run commands manually:

```bash
# Renew certificates
docker-compose -f docker-compose.yml -f docker-compose.prod.yml run --rm certbot renew

# Reload nginx
docker-compose -f docker-compose.yml -f docker-compose.prod.yml exec nginx nginx -s reload
```

## Testing Renewal

To test renewal without actually renewing:

```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml run --rm certbot renew --dry-run
```

## Troubleshooting

### Challenge files return 404

**Issue:** Certbot challenge files can't be accessed by the verification service.

**Check:**
1. Nginx is running: `docker-compose ps`
2. Port 80 is open: `sudo ufw status` or `sudo iptables -L`
3. DNS points to your server: `dig babloapp.com`
4. The webroot volume is properly mounted in docker-compose.prod.yml

### Certificates not found

**Issue:** Nginx can't find the certificate files.

**Solution:** Make sure `/etc/letsencrypt` on the host is mounted into nginx container (already configured in docker-compose.prod.yml line 26).

### Permission issues

**Issue:** Certbot can't write to the volume.

**Solution:** The certbot and nginx services share the `certbot_acme` volume, which should handle permissions automatically. If issues persist, check volume permissions:

```bash
docker volume inspect mymoney_certbot_acme
```
