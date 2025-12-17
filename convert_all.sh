#!/bin/bash

IMPORT_DIR="/mnt/audiobooks/Import"
EXPORT_DIR="/mnt/audiobooks/Export"
LOG_FILE="/var/log/audiobook_convert.log"
CONVERTED_LIST="/mnt/audiobooks/converted.list"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p "$IMPORT_DIR" "$EXPORT_DIR"
touch "$LOG_FILE" "$CONVERTED_LIST"

echo "$TIMESTAMP 🔍 Starting scan in $IMPORT_DIR" >> "$LOG_FILE"

for folder in "$IMPORT_DIR"/*; do
  [ -d "$folder" ] || continue
  folder_name=$(basename "$folder")
  lock_file="$folder/.lock"

  # Prüfen ob bereits konvertiert
  if grep -Fxq "$folder_name" "$CONVERTED_LIST"; then
    echo "$TIMESTAMP ⏭️  '$folder_name' already converted – skipping." >> "$LOG_FILE"
    continue
  fi

  # Prüfen ob gerade in Bearbeitung
  if [ -f "$lock_file" ]; then
    echo "$TIMESTAMP ⏳ '$folder_name' is currently being processed – skipping." >> "$LOG_FILE"
    continue
  fi

  # Sperrdatei setzen
  touch "$lock_file"
  echo "$TIMESTAMP 🎧 Converting '$folder_name'" >> "$LOG_FILE"

  (
    cd "$folder" || {
      echo "$TIMESTAMP ❌ Could not enter $folder_name" >> "$LOG_FILE"
      rm -f "$lock_file"
      exit 1
    }

    # Enable nullglob and case-insensitive matches so patterns without matches don't remain literal
    shopt -s nullglob nocaseglob

    chapter_file="chapters.txt"
    concat_list="filelist.txt"
    temp_audio="combined.m4a"
    sorted_list="sorted_files.txt"

    rm -f "$chapter_file" "$concat_list" "$temp_audio" "$sorted_list"

    # Unterstützte Formate: .m4a und .flac (case-insensitive)
    for f in *.m4a *.flac; do
      [ -f "$f" ] || continue

      cd_num=$(ffprobe -v error -show_entries format_tags=disc -of default=noprint_wrappers=1:nokey=1 "$f")
      track_num=$(ffprobe -v error -show_entries format_tags=track -of default=noprint_wrappers=1:nokey=1 "$f")
      title=$(ffprobe -v error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$f")

      cd_num=${cd_num:-0}
      track_num=${track_num:-0}
      title=${title:-${f%.*}}

      cd_num_clean=$(echo "$cd_num" | cut -d'/' -f1)
      track_num_clean=$(echo "$track_num" | cut -d'/' -f1)
      printf "%03d|%03d|%s|%s\n" "$cd_num_clean" "$track_num_clean" "$title" "$f" >> "$sorted_list"
    done

    # Wenn keine Dateien gefunden wurden, beenden
    if [ ! -s "$sorted_list" ]; then
      echo "$TIMESTAMP ⚠️ No supported audio files (.m4a/.flac) in $folder_name — skipping." >> "$LOG_FILE"
      rm -f "$chapter_file" "$concat_list" "$temp_audio" "$sorted_list" "$lock_file"
      exit 0
    fi

    sort "$sorted_list" > "${sorted_list}.tmp" && mv "${sorted_list}.tmp" "$sorted_list"

    offset=0
    echo "" > "$chapter_file"

    while IFS='|' read -r cd track title f; do
      # Vollqualifizierten Pfad in filelist schreiben; escape single quotes
      file_path="$PWD/$f"
      file_path_escaped=$(printf "%s" "$file_path" | sed "s/'/'\\\\''/g")
      echo "file '$file_path_escaped'" >> "$concat_list"

      duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$f")
      duration_ms=$(echo "$duration" | awk '{printf "%.0f", $1 * 1000}')

      echo "[CHAPTER]" >> "$chapter_file"
      echo "TIMEBASE=1/1000" >> "$chapter_file"
      echo "START=$offset" >> "$chapter_file"
      echo "END=$(($offset + $duration_ms))" >> "$chapter_file"
      echo "title=$title" >> "$chapter_file"

      offset=$(($offset + $duration_ms))
    done < "$sorted_list"

    # Beim Zusammenfügen re-encoden auf AAC, damit gemischte Formate (FLAC + M4A) zusammen funktionieren
    ffmpeg -f concat -safe 0 -i "$concat_list" -c:a aac -b:a 192k -ac 2 -y "$temp_audio"

    first_file=$(head -n 1 "$sorted_list" | cut -d'|' -f4)
    first_path="$PWD/$first_file"
    main_title=$(ffprobe -v error -show_entries format_tags=album -of default=noprint_wrappers=1:nokey=1 "$first_path")
    main_title=${main_title:-$folder_name}
    safe_title=$(echo "$main_title" | sed 's/[^[:alnum:]_-]/_/g' | sed 's/[_-]\{2,\}/_/g' | sed 's/^[_-]*//;s/[_-]*$//')
    final_file="${safe_title}.m4b"

    # Metadaten und Kapitel einfügen; Audiostream ist bereits AAC - kann kopiert werden
    ffmpeg -i "$temp_audio" -f ffmetadata -i "$chapter_file" -map 0 -map_metadata 1 \
      -metadata title="$main_title" \
      -c copy -y \
      "$final_file"

    if [ -f "$final_file" ]; then
      mv "$final_file" "$EXPORT_DIR/"
      echo "$folder_name" >> "$CONVERTED_LIST"
      echo "$(date '+%Y-%m-%d %H:%M:%S') ✅ Finished: $folder_name → $EXPORT_DIR/$final_file" >> "$LOG_FILE"
    else
      echo "$(date '+%Y-%m-%d %H:%M:%S') ❌ Conversion failed for $folder_name – no output file" >> "$LOG_FILE"
    fi

    rm -f "$chapter_file" "$concat_list" "$temp_audio" "$sorted_list" "$lock_file"
  ) &
done

wait
echo "$(date '+%Y-%m-%d %H:%M:%S') ✅ All conversions completed." >> "$LOG_FILE"
