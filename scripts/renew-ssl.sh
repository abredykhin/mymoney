#!/bin/bash

# Move to the project root directory
cd "$(dirname "$0")/.."

echo "Renewing SSL certificates using Docker..."

# Run certbot renewal using docker-compose
docker-compose -f docker-compose.yml -f docker-compose.prod.yml run --rm certbot renew

# Reload nginx to pick up renewed certificates
echo "Reloading nginx configuration..."
docker-compose -f docker-compose.yml -f docker-compose.prod.yml exec nginx nginx -s reload

echo "SSL certificate renewal complete!"
