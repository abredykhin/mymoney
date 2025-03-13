#!/bin/zsh

# Function to stream the latest log file
stream_latest_log() {
  latest_log=$(ls -t /opt/app-logs/*.log | head -n 1)
  if [[ -f "$latest_log" ]]; then
    # Use exec to replace the current shell process with tail -f
    exec tail -f "$latest_log"
  else
    echo "No log files found in /opt/app-logs."
  fi
}

# Call the function
stream_latest_log

