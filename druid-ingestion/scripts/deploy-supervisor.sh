#!/bin/bash
# deploy-supervisor.sh - Deploy Druid Kafka supervisor

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

[ $# -lt 1 ] && {
    echo "Usage: $0 <environment> [schema_version]" >&2
    exit 1
}

ENVIRONMENT=$1
SCHEMA_VERSION=${2:-"${ENVIRONMENT}-latest"}
export SCHEMA_VERSION

validate_environment "$ENVIRONMENT"
for cmd in envsubst jq curl; do check_command "$cmd"; done

echo "Deploying to $ENVIRONMENT (schema: $SCHEMA_VERSION)"

load_config "$ENVIRONMENT"
validate_vars "$MODULE_ROOT/config/${ENVIRONMENT}.env" \
    KAFKA_BOOTSTRAP_SERVERS KAFKA_TOPIC DATASOURCE_NAME DRUID_OVERLORD_URL

# Export all variables needed by envsubst (load_config sources the file but doesn't export)
export KAFKA_BOOTSTRAP_SERVERS KAFKA_SASL_JAAS_CONFIG KAFKA_TOPIC
export KAFKA_SECURITY_PROTOCOL KAFKA_SASL_MECHANISM KAFKA_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM
export PROTO_DESCRIPTOR_FILE PROTO_MESSAGE_TYPE
export DATASOURCE_NAME TIMESTAMP_COLUMN TIMESTAMP_FORMAT
export DRUID_OVERLORD_URL ENVIRONMENT
export SECONDARY_PARTITION_DIMENSIONS="${SECONDARY_PARTITION_DIMENSIONS:-[]}"
export PROTO_DESCRIPTOR_PATH="${PROTO_DESCRIPTOR_PATH:-}"
export S3_BUCKET="${S3_BUCKET:-my-company-druid-schemas}"
export MINIMUM_MESSAGE_TIME="${MINIMUM_MESSAGE_TIME:-1970-01-01T00:00:00.000Z}"

# Load dimensions
DIMENSIONS_FILE="$MODULE_ROOT/config/dimensions.json"
check_file "$DIMENSIONS_FILE"
DIMENSIONS_JSON=$(jq -c . "$DIMENSIONS_FILE" 2>/dev/null) || {
    echo "ERROR: Invalid JSON in dimensions file: $DIMENSIONS_FILE" >&2
    exit 1
}
export DIMENSIONS_JSON

# Load metrics
METRICS_FILE="$MODULE_ROOT/config/metrics.json"
check_file "$METRICS_FILE"
METRICS_JSON=$(jq -c . "$METRICS_FILE" 2>/dev/null) || {
    echo "ERROR: Invalid JSON in metrics file: $METRICS_FILE" >&2
    exit 1
}
export METRICS_JSON

# Load transforms
TRANSFORMS_FILE="$MODULE_ROOT/config/transforms.json"
check_file "$TRANSFORMS_FILE"
TRANSFORMS_JSON=$(jq -c . "$TRANSFORMS_FILE" 2>/dev/null) || {
    echo "ERROR: Invalid JSON in transforms file: $TRANSFORMS_FILE" >&2
    exit 1
}
export TRANSFORMS_JSON

# Load index spec
INDEX_SPEC_FILE="$MODULE_ROOT/config/index-spec.json"
check_file "$INDEX_SPEC_FILE"
INDEX_SPEC_JSON=$(jq -c . "$INDEX_SPEC_FILE" 2>/dev/null) || {
    echo "ERROR: Invalid JSON in index-spec file: $INDEX_SPEC_FILE" >&2
    exit 1
}
export INDEX_SPEC_JSON

if [ -z "${TX_TYPE_VALIDATION_FILTER:-}" ] || [ "${TX_TYPE_VALIDATION_FILTER}" = "null" ]; then
    export TX_TYPE_VALIDATION_FILTER="null"
fi


# Set default values for variables used in template (envsubst doesn't support ${VAR:-default})
export KAFKA_FETCH_MIN_BYTES="${KAFKA_FETCH_MIN_BYTES:-1048576}"
export KAFKA_FETCH_MAX_WAIT_MS="${KAFKA_FETCH_MAX_WAIT_MS:-500}"
export KAFKA_MAX_POLL_RECORDS="${KAFKA_MAX_POLL_RECORDS:-500}"
export KAFKA_SESSION_TIMEOUT_MS="${KAFKA_SESSION_TIMEOUT_MS:-30000}"
export KAFKA_HEARTBEAT_INTERVAL_MS="${KAFKA_HEARTBEAT_INTERVAL_MS:-3000}"
export KAFKA_MAX_POLL_INTERVAL_MS="${KAFKA_MAX_POLL_INTERVAL_MS:-300000}"
export KAFKA_AUTO_OFFSET_RESET="${KAFKA_AUTO_OFFSET_RESET:-latest}"
export USE_EARLIEST_OFFSET="${USE_EARLIEST_OFFSET:-false}"
export USE_TRANSACTION="${USE_TRANSACTION:-true}"
export TASK_COUNT="${TASK_COUNT:-10}"
export REPLICAS="${REPLICAS:-2}"
export TASK_DURATION="${TASK_DURATION:-PT1H}"
export START_DELAY="${START_DELAY:-PT5S}"
export PERIOD="${PERIOD:-PT30S}"
export COMPLETION_TIMEOUT="${COMPLETION_TIMEOUT:-PT1H}"
export LATE_MESSAGE_REJECTION_PERIOD="${LATE_MESSAGE_REJECTION_PERIOD:-PT1H}"
export POLL_TIMEOUT="${POLL_TIMEOUT:-100}"
export MINIMUM_MESSAGE_TIME="${MINIMUM_MESSAGE_TIME:-1970-01-01T00:00:00.000Z}"
export MAX_ROWS_IN_MEMORY="${MAX_ROWS_IN_MEMORY:-500000}"
export MAX_BYTES_IN_MEMORY="${MAX_BYTES_IN_MEMORY:-536870912}"
export MAX_ROWS_PER_SEGMENT="${MAX_ROWS_PER_SEGMENT:-5000000}"
export INTERMEDIATE_PERSIST_PERIOD="${INTERMEDIATE_PERSIST_PERIOD:-PT10M}"
export MAX_PENDING_PERSISTS="${MAX_PENDING_PERSISTS:-2}"
export REPORT_PARSE_EXCEPTIONS="${REPORT_PARSE_EXCEPTIONS:-true}"
export HANDOFF_CONDITION_TIMEOUT="${HANDOFF_CONDITION_TIMEOUT:-900000}"
export RESET_OFFSET_AUTOMATICALLY="${RESET_OFFSET_AUTOMATICALLY:-false}"
export CHAT_RETRIES="${CHAT_RETRIES:-8}"
export HTTP_TIMEOUT="${HTTP_TIMEOUT:-PT10S}"
export SHUTDOWN_TIMEOUT="${SHUTDOWN_TIMEOUT:-PT80S}"
export OFFSET_FETCH_PERIOD="${OFFSET_FETCH_PERIOD:-PT30S}"
export INTERMEDIATE_HANDOFF_PERIOD="${INTERMEDIATE_HANDOFF_PERIOD:-P2147483647D}"
export LOG_PARSE_EXCEPTIONS="${LOG_PARSE_EXCEPTIONS:-true}"
export MAX_PARSE_EXCEPTIONS="${MAX_PARSE_EXCEPTIONS:-10000}"
export MAX_SAVED_PARSE_EXCEPTIONS="${MAX_SAVED_PARSE_EXCEPTIONS:-100}"
export SKIP_SEQUENCE_NUMBER_AVAILABILITY_CHECK="${SKIP_SEQUENCE_NUMBER_AVAILABILITY_CHECK:-false}"
export PARTITIONS_SPEC_TYPE="${PARTITIONS_SPEC_TYPE:-dynamic}"
export TARGET_ROWS_PER_SEGMENT="${TARGET_ROWS_PER_SEGMENT:-5000000}"
export MAX_SPLIT_SIZE="${MAX_SPLIT_SIZE:-1073741824}"
export MAX_INPUT_SEGMENT_BYTES_PER_TASK="${MAX_INPUT_SEGMENT_BYTES_PER_TASK:-10737418240}"
export SEGMENT_GRANULARITY="${SEGMENT_GRANULARITY:-DAY}"
export QUERY_GRANULARITY="${QUERY_GRANULARITY:-NONE}"
export ROLLUP="${ROLLUP:-false}"

# Handle PROTO_DESCRIPTOR_PATH with default S3 path if not set
if [ -z "${PROTO_DESCRIPTOR_PATH:-}" ]; then
    export PROTO_DESCRIPTOR_PATH="s3://${S3_BUCKET:-my-company-druid-schemas}/schemas/${SCHEMA_VERSION:-${ENVIRONMENT}-latest}/${PROTO_DESCRIPTOR_FILE:-settlement_transaction.desc}"
fi
export PROTO_DESCRIPTOR_PATH

# Determine decoder type and path format
export PROTO_DECODER_TYPE="file"
# Keep file:// prefix for local paths (Druid FileBasedProtobufBytesDecoder expects file:// prefix)
# Keep s3:// prefix for S3 paths
if [[ "${PROTO_DESCRIPTOR_PATH}" == file://* ]]; then
    export PROTO_DESCRIPTOR_PATH_CLEAN="${PROTO_DESCRIPTOR_PATH}"
elif [[ "${PROTO_DESCRIPTOR_PATH}" == s3://* ]]; then
    export PROTO_DESCRIPTOR_PATH_CLEAN="${PROTO_DESCRIPTOR_PATH}"
else
    # Assume local file path (add file:// prefix)
    export PROTO_DESCRIPTOR_PATH_CLEAN="file://${PROTO_DESCRIPTOR_PATH}"
fi
export PROTO_DECODER_TYPE
export PROTO_DESCRIPTOR_PATH_CLEAN

TEMPLATE_FILE="$MODULE_ROOT/druid-specs/templates/kafka-supervisor.json"
OUTPUT_DIR="$MODULE_ROOT/druid-specs/generated"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/supervisor-spec-${ENVIRONMENT}.json"
check_file "$TEMPLATE_FILE"

envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE" || {
    echo "ERROR: Failed to generate supervisor spec from template" >&2
    exit 1
}

jq empty "$OUTPUT_FILE" 2>/dev/null || {
    echo "ERROR: Generated supervisor spec contains invalid JSON" >&2
    exit 1
}

echo "Generated supervisor spec: $OUTPUT_FILE"
jq -r '"  Datasource: \(.spec.dataSchema.dataSource)\n  Topic: \(.spec.ioConfig.topic)\n  Tasks: \(.spec.ioConfig.taskCount)"' "$OUTPUT_FILE"

# Production confirmation
[ "$ENVIRONMENT" = "prod" ] && {
    echo ""
    read -p "Deploy to PRODUCTION? (yes/no): " -r
    [[ ! $REPLY =~ ^[Yy]es$ ]] && { echo "Deployment cancelled"; exit 0; }
}

# Deploy to Druid
echo "Deploying supervisor to Druid..."
TMP_RESPONSE=$(mktemp)
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TMP_RESPONSE" \
    -X POST -H 'Content-Type: application/json' \
    -d @"$OUTPUT_FILE" \
    "${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor" || echo "000")
RESPONSE_BODY=$(cat "$TMP_RESPONSE" 2>/dev/null || echo "")
rm -f "$TMP_RESPONSE"

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    echo "Deployment successful (HTTP $HTTP_CODE)"
    [ -n "$RESPONSE_BODY" ] && echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
    echo ""
    echo "Druid console: ${DRUID_OVERLORD_URL}/unified-console.html#supervisors"
else
    echo "ERROR: Deployment failed (HTTP $HTTP_CODE)" >&2
    [ -n "$RESPONSE_BODY" ] && echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
    exit 1
fi
