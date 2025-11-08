#!/bin/bash

echo "🔍 Checking system requirements for Audio Book Compiler..."

# Minimum versions
REQUIRED_FFMPEG="4.0"
REQUIRED_FFPROBE="4.0"
REQUIRED_BASH="4.4"
REQUIRED_BC="1.06"

# Version comparison helper
version_ge() {
  [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

# Tool check function with install prompt
check_tool() {
  local tool=$1
  local required=$2
  local version_cmd=$3
  local package_name=$4

  if ! command -v "$tool" &>/dev/null; then
    echo "❌ $tool not found in PATH"

    read -p "❓ Install $tool now? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      echo "📦 Installing $tool..."
      sudo apt update && sudo apt install -y "$package_name"
      if command -v "$tool" &>/dev/null; then
        echo "✅ $tool installed successfully"
      else
        echo "❌ Failed to install $tool"
      fi
    else
      echo "⚠️  $tool is required but not installed"
    fi
    return
  fi

  local version=$($version_cmd 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
  echo "✅ $tool found (version $version)"

  if version_ge "$version" "$required"; then
    echo "✅ $tool meets minimum version $required"
  else
    echo "⚠️  $tool version $version is below required $required"
  fi
}

# Check tools
check_tool ffmpeg "$REQUIRED_FFMPEG" "ffmpeg -version" "ffmpeg"
check_tool ffprobe "$REQUIRED_FFPROBE" "ffprobe -version" "ffmpeg"
check_tool bash "$REQUIRED_BASH" "bash --version" "bash"
check_tool bc "$REQUIRED_BC" "bc --version" "bc"

echo "✅ Requirement check completed."
