#!/bin/zsh

docker-compose down -v --remove-orphans && docker-compose -f docer-compose.yml docker-compose.prod.yml up --build -d
