#!/usr/bin/env bash
set -euo pipefail

store_path="${1:-}"
if [ -z "$store_path" ] || [ ! -d "$store_path" ]; then
  exit 0
fi

find "$store_path" -name "integrity-not-built.json" -print0 \
  | while IFS= read -r -d "" file; do
      if jq -e '.requiresBuild == true' "$file" >/dev/null; then
        continue
      fi
      cp "$file" "${file%integrity-not-built.json}integrity.json"
    done
