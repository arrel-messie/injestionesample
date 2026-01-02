#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

[ $# -lt 1 ] && { echo "Usage: $0 <environment> [schema_version]" >&2; exit 1; }

ENV=$1
SCHEMA_VERSION=${2:-"${ENV}-latest"}

validate_environment "$ENV"
for cmd in envsubst jq curl; do check_command "$cmd"; done

load_config "$ENV"
validate_vars "$MODULE_ROOT/config/${ENV}.env" \
    KAFKA_BOOTSTRAP_SERVERS KAFKA_TOPIC DATASOURCE_NAME DRUID_OVERLORD_URL

# Generate spec
OUTPUT=$("$SCRIPT_DIR/generate-spec.sh" "$ENV" "$SCHEMA_VERSION")

echo "Deploying to $ENV (schema: $SCHEMA_VERSION)"
jq -r '"  Datasource: \(.spec.dataSchema.dataSource)\n  Topic: \(.spec.ioConfig.topic)\n  Tasks: \(.spec.ioConfig.taskCount)"' "$OUTPUT"

[ "$ENV" = "prod" ] && {
    read -p "Deploy to PRODUCTION? (yes/no): " -r
    [[ ! $REPLY =~ ^[Yy]es$ ]] && { echo "Cancelled"; exit 0; }
}

# Deploy
TMP=$(mktemp)
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TMP" -X POST -H 'Content-Type: application/json' \
    -d @"$OUTPUT" "${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor" || echo "000")
RESPONSE=$(cat "$TMP")
rm -f "$TMP"

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    echo "Deployment successful (HTTP $HTTP_CODE)"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    echo "Druid console: ${DRUID_OVERLORD_URL}/unified-console.html#supervisors"
else
    echo "ERROR: Deployment failed (HTTP $HTTP_CODE)" >&2
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    exit 1
fi
