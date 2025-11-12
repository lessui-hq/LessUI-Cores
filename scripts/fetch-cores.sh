#!/bin/bash
# Fetch/update core repositories from recipe file
set -e

RECIPE_FILE="$1"
CORES_DIR="${2:-cores}"

if [ -z "$RECIPE_FILE" ] || [ ! -f "$RECIPE_FILE" ]; then
    echo "Usage: $0 <recipe-file> [cores-dir]"
    exit 1
fi

mkdir -p "$CORES_DIR"

echo "=== Fetching cores from $RECIPE_FILE ==="

while read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue

    # Parse: name dir url branch enabled build_type makefile subdir args...
    read -r name dir url branch enabled rest <<< "$line"

    # Skip if not enabled
    [ "$enabled" != "YES" ] && continue

    echo "→ $name"

    if [ -d "$CORES_DIR/$dir" ]; then
        # Update existing repo
        cd "$CORES_DIR/$dir"
        git fetch origin
        git checkout "$branch"
        git pull origin "$branch" || true
        cd - > /dev/null
    else
        # Clone new repo
        git clone --depth 1 -b "$branch" "$url" "$CORES_DIR/$dir"
    fi

done < "$RECIPE_FILE"

echo "✓ Fetch complete"
