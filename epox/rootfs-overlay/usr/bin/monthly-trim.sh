#!/bin/bash

STATE_FILE="/var/lib/monthly-trim/last-run"
LOG_FILE="/var/log/monthly-trim.log"

mkdir -p /var/lib/monthly-trim

# Run only if 30 days have passed
if [ -f "$STATE_FILE" ]; then
    LAST_RUN=$(cat "$STATE_FILE")
    NOW=$(date +%s)

    AGE=$((NOW - LAST_RUN))

    if [ "$AGE" -lt 2592000 ]; then
        exit 0
    fi
fi

{
    echo "=== Monthly trim started: $(date) ==="

    fstrim -av

    echo "=== Finished: $(date) ==="
} >> "$LOG_FILE" 2>&1

date +%s > "$STATE_FILE"
