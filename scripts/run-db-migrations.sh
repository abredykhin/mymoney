#!/bin/zsh

# Move to the project root directory
cd "$(dirname "$0")/.."

docker-compose exec server knex migrate:latest
