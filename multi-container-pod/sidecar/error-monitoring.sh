#!/bin/bash

LOG_FILE="/var/log/nginx/error.log"
LAST_LINE_NUM=0

# Check if the log file exists and is readable
if [ ! -r "$LOG_FILE" ]; then
  echo "Log file $LOG_FILE does not exist or is not readable."
  exit 1
fi

while true; do
  # Get the total number of lines in the log file
  CURRENT_LINE_NUM=$(wc -l < "$LOG_FILE")

  # If the log file has new lines, process them
  if [ "$CURRENT_LINE_NUM" -gt "$LAST_LINE_NUM" ]; then
    # Extract new lines
    NEW_LINES=$(tail -n +"$((LAST_LINE_NUM + 1))" "$LOG_FILE")
    
    # Filter for lines containing 'error' and send to standard output
    echo "$NEW_LINES" | grep -i "error" | while IFS= read -r LINE; do
      echo "[ERROR DETECTED] $LINE"
    done

    # Update the last processed line number
    LAST_LINE_NUM=$CURRENT_LINE_NUM
  fi

  # Wait for 10 seconds before checking again
  sleep 10
done
