#!/usr/bin/env bash
#
# Migration script: defaults.json → .env.example
# Convertit defaults.json en format .env complet
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config"
DEFAULTS_FILE="${CONFIG_DIR}/defaults.json"
OUTPUT_FILE="${CONFIG_DIR}/.env.example"

[ ! -f "$DEFAULTS_FILE" ] && echo "Error: defaults.json not found" && exit 1

# Helper to convert camelCase to UPPER_SNAKE_CASE
_to_snake_case() {
    echo "$1" | sed 's/\([a-z]\)\([A-Z]\)/\1_\2/g' | tr '[:lower:]' '[:upper:]'
}

echo "# Generated from defaults.json"
echo "# Complete environment configuration template"
echo "# Copy this file to dev.env, staging.env, prod.env and adjust values"
echo ""

# Convert JSON to .env format
jq -r '
  .kafka | to_entries[] | "KAFKA_\(.key | ascii_upcase | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)") | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)"))=\"\(.value)\""
' "$DEFAULTS_FILE" | while IFS='=' read -r key value; do
    [ -n "$key" ] && echo "$key=$value"
done

jq -r '
  .proto | to_entries[] | "PROTO_\(.key | ascii_upcase | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)") | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)"))=\"\(.value)\""
' "$DEFAULTS_FILE" | while IFS='=' read -r key value; do
    [ -n "$key" ] && echo "$key=$value"
done

jq -r '
  .druid | to_entries[] | 
    if .key == "url" then "DRUID_URL=\"\(.value)\""
    elif .key == "datasource" then "DATASOURCE=\"\(.value)\""
    elif .key == "timestampColumn" then "DRUID_TIMESTAMP_COLUMN=\"\(.value)\""
    elif .key == "timestampFormat" then "DRUID_TIMESTAMP_FORMAT=\"\(.value)\""
    else "DRUID_\(.key | ascii_upcase | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)") | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)"))=\"\(.value)\""
    end
' "$DEFAULTS_FILE"

jq -r '
  .task | to_entries[] | "TASK_\(.key | ascii_upcase | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)") | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)"))=\"\(.value)\""
' "$DEFAULTS_FILE" | while IFS='=' read -r key value; do
    [ -n "$key" ] && echo "$key=$value"
done

jq -r '
  .tuning | to_entries[] | "TUNING_\(.key | ascii_upcase | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)") | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)"))=\"\(.value)\""
' "$DEFAULTS_FILE" | while IFS='=' read -r key value; do
    [ -n "$key" ] && echo "$key=$value"
done

jq -r '
  .granularity | to_entries[] | "GRANULARITY_\(.key | ascii_upcase)=\"\(.value)\""
' "$DEFAULTS_FILE"

echo ""
echo "# Index Spec (can also come from schema.json)"
echo "INDEX_SPEC_BITMAP_TYPE=roaring"
echo "INDEX_SPEC_DIMENSION_COMPRESSION=lz4"
echo "INDEX_SPEC_METRIC_COMPRESSION=lz4"
echo "INDEX_SPEC_LONG_ENCODING=longs"

