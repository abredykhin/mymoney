#!/bin/bash

# Get the ID of the container named "mymoney_server_1"
container_id=$(docker ps -q --filter "name=mymoney_server_1")

# Check if the container exists
if [ -n "$container_id" ]; then
  # Print the logs of the container
  docker logs "$container_id"
else
  echo "Error: No container named 'mymoney_server_1' found."
fi
