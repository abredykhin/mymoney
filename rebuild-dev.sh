#!/bin/zsh

docker-compose down -v --remove-orphans && docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --build
