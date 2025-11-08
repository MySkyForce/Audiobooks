#!/bin/bash

UPLOAD_DIR="/mnt/audiobooks/Upload"
IMPORT_DIR="/mnt/audiobooks/Import"
CACHE_FILE="/tmp/audiobook_sizecache.txt"

mkdir -p "$IMPORT_DIR"
touch "$CACHE_FILE"

# Hilfsfunktion: aktuelle Größe holen
get_size() {
  du -sb "$1" 2>/dev/null | cut -f1
}

# Durchlaufe alle Unterordner
for folder in "$UPLOAD_DIR"/*; do
  [ -d "$folder" ] || continue
  folder_name=$(basename "$folder")
  current_size=$(get_size "$folder")

  # Vorherige Größe aus Cache holen
  previous_size=$(grep "^$folder_name|" "$CACHE_FILE" | cut -d'|' -f2)

  if [ "$current_size" = "$previous_size" ] && [ -n "$previous_size" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') 📦 '$folder_name' ist stabil – wird verschoben."
    mv "$folder" "$IMPORT_DIR/"
    # Aus Cache entfernen
    sed -i "/^$folder_name|/d" "$CACHE_FILE"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') ⏳ '$folder_name' wird noch beschrieben – bleibt im Upload."
    # Cache aktualisieren
    sed -i "/^$folder_name|/d" "$CACHE_FILE"
    echo "$folder_name|$current_size" >> "$CACHE_FILE"
  fi
done

