#!/bin/zsh

docker-compose exec server knex migrate:latest
