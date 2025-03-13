#!/bin/bash

# Configuration
LOG_DIR="/opt/app-logs"
ERROR_LOG="$LOG_DIR/error.log"
EXCEPTIONS_LOG="$LOG_DIR/exceptions.log"
HOURS_THRESHOLD=6
TAIL_LINES=100

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --hours=*) HOURS_THRESHOLD="${1#*=}" ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# ANSI color codes for better readability
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
MAGENTA='\033[0;35m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to get the latest app log file
get_latest_app_log() {
    ls -t "$LOG_DIR"/*-app.log 2>/dev/null | head -n 1
}

# Function to check if a timestamp is within the last N hours
is_within_last_hours() {
    timestamp="$1"
    hours="$2"
    
    # Parse the timestamp
    log_time=$(date -d "$timestamp" +%s 2>/dev/null)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Current time
    now=$(date +%s)
    
    # Calculate the difference in hours
    diff_seconds=$((now - log_time))
    diff_hours=$((diff_seconds / 3600))
    
    # Check if within threshold
    [ $diff_hours -le $hours ]
}

# Function to colorize a log line based on its content
colorize_log_line() {
    local line="$1"
    
    # Check if the line has a timestamp
    if [[ "$line" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z) ]]; then
        timestamp="${BASH_REMATCH[1]}"
        rest="${line#$timestamp}"
        
        # Color based on log level
        if [[ "$rest" == *" error:"* ]]; then
            echo -e "${GRAY}${timestamp}${NC}${RED}${rest}${NC}"
        elif [[ "$rest" == *" warn:"* ]]; then
            echo -e "${GRAY}${timestamp}${NC}${YELLOW}${rest}${NC}"
        elif [[ "$rest" == *" info:"* ]]; then
            echo -e "${GRAY}${timestamp}${NC}${BLUE}${rest}${NC}"
        elif [[ "$rest" == *" debug:"* ]]; then
            echo -e "${GRAY}${timestamp}${NC}${CYAN}${rest}${NC}"
        else
            echo -e "${GRAY}${timestamp}${NC}${rest}"
        fi
    else
        echo "$line"
    fi
}

# Function to check for recent errors and exceptions
check_recent_errors() {
    local hours=$1
    echo -e "\n${BOLD}${MAGENTA}=== Checking for errors/exceptions in the last $hours hours ===${NC}\n"
    
    local found_recent_errors=false
    
    # Check error.log
    if [ -f "$ERROR_LOG" ]; then
        while IFS= read -r line; do
            if [ -z "$line" ]; then
                continue
            fi
            
            # Extract timestamp
            if [[ "$line" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z) ]]; then
                timestamp="${BASH_REMATCH[1]}"
                
                if is_within_last_hours "$timestamp" "$hours"; then
                    if [ "$found_recent_errors" = false ]; then
                        echo -e "${RED}Recent errors found:${NC}"
                        found_recent_errors=true
                    fi
                    echo -e "${RED}$line${NC}"
                fi
            fi
        done < "$ERROR_LOG"
    fi
    
    # Check exceptions.log
    if [ -f "$EXCEPTIONS_LOG" ]; then
        # Read file into an array
        mapfile -t exception_lines < "$EXCEPTIONS_LOG"
        
        i=0
        while [ $i -lt ${#exception_lines[@]} ]; do
            line="${exception_lines[$i]}"
            
            # Skip empty lines
            if [ -z "$line" ]; then
                ((i++))
                continue
            fi
            
            # Extract timestamp from the start of an exception block
            if [[ "$line" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z) ]]; then
                timestamp="${BASH_REMATCH[1]}"
                exception_block="$line"
                
                # Collect the whole exception block
                j=$((i + 1))
                while [ $j -lt ${#exception_lines[@]} ] && ! [[ "${exception_lines[$j]}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; do
                    exception_block+=$'\n'"${exception_lines[$j]}"
                    ((j++))
                done
                
                if is_within_last_hours "$timestamp" "$hours"; then
                    if [ "$found_recent_errors" = false ]; then
                        echo -e "${RED}Recent exceptions found:${NC}"
                        found_recent_errors=true
                    fi
                    echo -e "${RED}$exception_block${NC}"
                fi
                
                i=$j
            else
                ((i++))
            fi
        done
    fi
    
    if [ "$found_recent_errors" = false ]; then
        echo -e "${GREEN}No recent errors or exceptions found.${NC}"
    fi
    
    return 0
}

# Function to stream the latest logs in chronological order
stream_latest_logs() {
    local latest_log_file=$(get_latest_app_log)
    
    if [ -z "$latest_log_file" ]; then
        echo "No app log files found!"
        exit 1
    fi
    
    echo -e "\n${BOLD}${MAGENTA}=== Streaming logs from $(basename "$latest_log_file") ===${NC}\n"
    
    # Get the last N lines from the log file and sort them chronologically
    sort_logs_chronologically "$latest_log_file" "$TAIL_LINES"
    
    echo -e "\n${BOLD}${MAGENTA}=== Now streaming new log entries (Ctrl+C to exit) ===${NC}\n"
    
    # Use tail -f to follow the file
    tail -f "$latest_log_file" | while IFS= read -r line; do
        colorize_log_line "$line"
    done
}

# Function to sort logs chronologically
sort_logs_chronologically() {
    local log_file="$1"
    local num_lines="$2"
    
    # Get the last N lines and sort them by timestamp
    tail -n "$num_lines" "$log_file" | sort -t 'T' -k1,1 -k2,2 | while IFS= read -r line; do
        colorize_log_line "$line"
    done
}

# Main function
main() {
    echo -e "${BOLD}${MAGENTA}=== Log Monitor Starting ===${NC}"
    echo "Checking for errors in the last $HOURS_THRESHOLD hours..."
    
    # Check for recent errors
    check_recent_errors "$HOURS_THRESHOLD"
    
    # Stream logs from the latest app log file
    stream_latest_logs
}

# Start the script
main

