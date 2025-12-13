#!/bin/bash

# Move to the project root directory
cd "$(dirname "$0")/.."

# Configuration
DOMAIN="babloapp.com"
EMAIL="your-email@example.com"  # CHANGE THIS to your email

echo "Obtaining SSL certificates for $DOMAIN and www.$DOMAIN..."
echo "Make sure nginx is running and accessible on port 80!"
echo ""

# Obtain certificate using docker-compose certbot service
docker-compose -f docker-compose.yml -f docker-compose.prod.yml run --rm certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email \
  -d "$DOMAIN" \
  -d "www.$DOMAIN"

if [ $? -eq 0 ]; then
  echo ""
  echo "SSL certificates obtained successfully!"
  echo "Reloading nginx configuration..."
  docker-compose -f docker-compose.yml -f docker-compose.prod.yml exec nginx nginx -s reload
  echo "Done!"
else
  echo ""
  echo "Failed to obtain SSL certificates. Check the error messages above."
  echo "Common issues:"
  echo "  1. Make sure your domain DNS points to this server"
  echo "  2. Make sure port 80 is accessible from the internet"
  echo "  3. Make sure nginx is running: docker-compose ps"
  exit 1
fi
