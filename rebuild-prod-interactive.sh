#!/bin/zsh

docker-compose down -v --remove-orphans && docker-compose -f docker-compose.yml -f docker-compose.prod.yml up --build
