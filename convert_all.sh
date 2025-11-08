#!/bin/bash

IMPORT_DIR="/mnt/audiobooks/Import"
DONE_DIR="/mnt/audiobooks/Done"
EXPORT_DIR="/mnt/audiobooks/Export"
LOG_FILE="/var/log/audiobook_convert.log"
CONVERTED_LIST="$DONE_DIR/converted.list"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p "$IMPORT_DIR" "$DONE_DIR" "$EXPORT_DIR"
touch "$LOG_FILE" "$CONVERTED_LIST"

echo "$TIMESTAMP 🔍 Starting scan in $IMPORT_DIR" >> "$LOG_FILE"

# Schritt 1: Neue Ordner nach Done kopieren
for folder in "$IMPORT_DIR"/*; do
  [ -d "$folder" ] || continue
  folder_name=$(basename "$folder")

  if [ -d "$DONE_DIR/$folder_name" ]; then
    echo "$TIMESTAMP ⏭️  '$folder_name' already in Done – skipping copy." >> "$LOG_FILE"
    continue
  fi

  cp -r "$folder" "$DONE_DIR/$folder_name"
  echo "$TIMESTAMP 📦 Copied '$folder_name' to Done." >> "$LOG_FILE"
done

# Schritt 2: Konvertierung aus Done-Verzeichnis
for folder in "$DONE_DIR"/*; do
  [ -d "$folder" ] || continue
  folder_name=$(basename "$folder")

  # Prüfen ob bereits konvertiert laut Liste
  if grep -Fxq "$folder_name" "$CONVERTED_LIST"; then
    echo "$TIMESTAMP ⏭️  '$folder_name' already listed as converted – skipping." >> "$LOG_FILE"
    continue
  fi

  echo "$TIMESTAMP 🎧 Converting '$folder_name'" >> "$LOG_FILE"

  (
    cd "$folder" || {
      echo "$TIMESTAMP ❌ Could not enter $folder_name" >> "$LOG_FILE"
      exit 1
    }

    chapter_file="chapters.txt"
    concat_list="filelist.txt"
    temp_audio="combined.m4a"
    sorted_list="sorted_files.txt"

    rm -f "$chapter_file" "$concat_list" "$temp_audio" "$sorted_list"

    for f in *.m4a; do
      [ -f "$f" ] || continue

      cd_num=$(ffprobe -v error -show_entries format_tags=disc -of default=noprint_wrappers=1:nokey=1 "$f")
      track_num=$(ffprobe -v error -show_entries format_tags=track -of default=noprint_wrappers=1:nokey=1 "$f")
      title=$(ffprobe -v error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$f")

      cd_num=${cd_num:-0}
      track_num=${track_num:-0}
      title=${title:-$(basename "$f" .m4a)}

      cd_num_clean=$(echo "$cd_num" | cut -d'/' -f1)
      track_num_clean=$(echo "$track_num" | cut -d'/' -f1)
      printf "%03d|%03d|%s|%s\n" "$cd_num_clean" "$track_num_clean" "$title" "$f" >> "$sorted_list"
    done

    sort "$sorted_list" > "${sorted_list}.tmp" && mv "${sorted_list}.tmp" "$sorted_list"

    offset=0
    echo "" > "$chapter_file"

    while IFS='|' read -r cd track title f; do
      echo "file '$PWD/$f'" >> "$concat_list"

      duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$f")
      duration_ms=$(echo "$duration" | awk '{printf "%.0f", $1 * 1000}')

      echo "[CHAPTER]" >> "$chapter_file"
      echo "TIMEBASE=1/1000" >> "$chapter_file"
      echo "START=$offset" >> "$chapter_file"
      echo "END=$(($offset + $duration_ms))" >> "$chapter_file"
      echo "title=$title" >> "$chapter_file"

      offset=$(($offset + $duration_ms))
    done < "$sorted_list"

    ffmpeg -f concat -safe 0 -i "$concat_list" -c copy "$temp_audio"

    first_file=$(head -n 1 "$sorted_list" | cut -d'|' -f4)
    main_title=$(ffprobe -v error -show_entries format_tags=album -of default=noprint_wrappers=1:nokey=1 "$first_file")
    main_title=${main_title:-$folder_name}
    safe_title=$(echo "$main_title" | sed 's/[^[:alnum:]_-]/_/g')
    final_file="${safe_title}.m4b"

    ffmpeg -i "$temp_audio" -f ffmetadata -i "$chapter_file" -map_metadata 1 \
      -metadata title="$main_title" \
      -c:a aac -b:a 192k -ac 2 \
      "$final_file"

    if [ -f "$final_file" ]; then
      mv "$final_file" "$EXPORT_DIR/"
      echo "$folder_name" >> "$CONVERTED_LIST"
      echo "$(date '+%Y-%m-%d %H:%M:%S') ✅ Finished: $folder_name → $EXPORT_DIR/$final_file" >> "$LOG_FILE"
    else
      echo "$(date '+%Y-%m-%d %H:%M:%S') ❌ Conversion failed for $folder_name – no output file" >> "$LOG_FILE"
    fi

    rm -f "$chapter_file" "$concat_list" "$temp_audio" "$sorted_list"
  ) &
done

wait
echo "$(date '+%Y-%m-%d %H:%M:%S') ✅ All conversions completed." >> "$LOG_FILE"

