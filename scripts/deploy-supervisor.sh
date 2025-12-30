#!/bin/bash
# scripts/deploy-supervisor.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

[ $# -lt 1 ] && {
    echo "Usage: $0 <environment> [schema_version]"
    echo "  environment: dev, staging, prod"
    echo "  schema_version: optional, default: {env}-latest"
    exit 1
}

ENVIRONMENT=$1
SCHEMA_VERSION=${2:-"${ENVIRONMENT}-latest"}

[[ "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]] || {
    echo "Invalid environment: $ENVIRONMENT (use: dev, staging, prod)"
    exit 1
}

echo "Deploying to $ENVIRONMENT (schema: $SCHEMA_VERSION)"

# Check dependencies
command -v envsubst >/dev/null 2>&1 || { echo "envsubst missing"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq missing"; exit 1; }

# Load config
CONFIG_FILE="$PROJECT_ROOT/config/${ENVIRONMENT}.env"
[ -f "$CONFIG_FILE" ] || { echo "Config not found: $CONFIG_FILE"; exit 1; }
source "$CONFIG_FILE"

# Load dimensions
DIMENSIONS_FILE="$PROJECT_ROOT/config/dimensions.json"
[ -f "$DIMENSIONS_FILE" ] || { echo "dimensions.json not found"; exit 1; }
export DIMENSIONS_JSON=$(jq -c . "$DIMENSIONS_FILE")

# Generate spec
TEMPLATE_FILE="$PROJECT_ROOT/druid-specs/templates/kafka-supervisor.json"
OUTPUT_FILE="$PROJECT_ROOT/supervisor-spec-${ENVIRONMENT}.json"

envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"
jq empty "$OUTPUT_FILE" || { echo "Invalid JSON generated"; exit 1; }

echo "Generated: $OUTPUT_FILE"
echo "  Datasource: $(jq -r '.spec.dataSchema.dataSource' "$OUTPUT_FILE")"
echo "  Topic: $(jq -r '.spec.ioConfig.topic' "$OUTPUT_FILE")"
echo "  Tasks: $(jq -r '.spec.ioConfig.taskCount' "$OUTPUT_FILE")"

# Prod confirmation
if [ "$ENVIRONMENT" = "prod" ]; then
    read -p "Deploy to PRODUCTION? (yes/no): " -r
    [[ $REPLY =~ ^[Yy]es$ ]] || { echo "Cancelled"; exit 0; }
fi

# Deploy
response=$(curl -s -w "\n%{http_code}" -X POST \
    -H 'Content-Type: application/json' \
    -d @"$OUTPUT_FILE" \
    "${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    echo "Deployment successful (HTTP $http_code)"
    echo "$body" | jq . 2>/dev/null || echo "$body"
    echo "Console: ${DRUID_OVERLORD_URL}/unified-console.html#supervisors"
else
    echo "Deployment failed (HTTP $http_code)"
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
fi