#!/bin/bash

DONE_DIR="/mnt/audiobooks/Done"
LOG_FILE="/var/log/audiobook_convert.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "$TIMESTAMP 🧹 Starting cleanup of Done directory..." >> "$LOG_FILE"

# Nur Unterordner löschen, nicht converted.list
find "$DONE_DIR" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +

echo "$TIMESTAMP ✅ Cleanup completed." >> "$LOG_FILE"

