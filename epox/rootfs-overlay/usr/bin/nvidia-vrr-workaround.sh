#!/usr/bin/env bash

LOG_DIR="$HOME/.cache/nvidia-fix"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/nvidia-vrr.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

log "Script started (PID $$)"

if [[ -f "$LOG_FILE" ]] && (( $(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) > 1048576 )); then
    mv "$LOG_FILE" "$LOG_FILE.old"
    log "Log rotated"
fi

LAST_RUN=0
WAS_ACTIVE=false

ACTIVE=$(busctl --user get-property org.gnome.ScreenSaver /org/gnome/ScreenSaver org.gnome.ScreenSaver Active 2>/dev/null)
if [[ "$ACTIVE" == *"true"* ]]; then
    WAS_ACTIVE=true
    log "Initial state: screen locked"
else
    log "Initial state: screen unlocked"
fi

while true; do
    ACTIVE=$(busctl --user get-property org.gnome.ScreenSaver /org/gnome/ScreenSaver org.gnome.ScreenSaver Active 2>/dev/null)

    if [[ "$ACTIVE" == *"true"* ]]; then
        WAS_ACTIVE=true
    elif [[ "$ACTIVE" == *"false"* ]] && [[ "$WAS_ACTIVE" == "true" ]]; then
        CURRENT_TIME=$(date +%s)

        if (( CURRENT_TIME - LAST_RUN > 5 )); then
            LAST_RUN=$CURRENT_TIME
            WAS_ACTIVE=false

            log "Screen unlocked, triggering modeset"

            sleep 2

            if busctl --user set-property \
                org.gnome.Mutter.DisplayConfig \
                /org/gnome/Mutter/DisplayConfig \
                org.gnome.Mutter.DisplayConfig \
                PowerSaveMode i 3 2>>"$LOG_FILE"; then
                log "Displays turned off"
            else
                log "ERROR: Failed to turn off displays"
            fi

            sleep 1

            if busctl --user set-property \
                org.gnome.Mutter.DisplayConfig \
                /org/gnome/Mutter/DisplayConfig \
                org.gnome.Mutter.DisplayConfig \
                PowerSaveMode i 0 2>>"$LOG_FILE"; then
                log "Displays turned on"
            else
                log "ERROR: Failed to turn on displays"
            fi
        fi
    fi

    sleep 1
done

