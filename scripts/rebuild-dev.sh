#!/bin/zsh

# Move to the project root directory
cd "$(dirname "$0")/.."

docker-compose down --remove-orphans && docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --build
