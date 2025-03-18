#!/bin/zsh

# Move to the project root directory
cd "$(dirname "$0")/.."

# Stop and remove containers but preserve volumes and networks
docker-compose down --remove-orphans

# Build with cache reuse for faster builds
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache=false --pull

# Start the containers
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
