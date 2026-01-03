#!/usr/bin/env bash
#
# Spec Builder - Optimized with generic functions
#

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Generic spec builder
_build_spec() {
    local schema_file="$1" jq_expr="$2" default="$3"
    jq -c "$jq_expr" "$schema_file" 2>/dev/null || echo "$default"
}

# Build dimensions spec from schema.json
_build_dimensions_spec() {
    _build_spec "$1" '{
        dimensions: (.dimensions // []),
        dimensionExclusions: ["settlement_ts", "settlement_entry_ts", "acceptance_ts", "payee_access_manager_id"],
        includeAllDimensions: false,
        useSchemaDiscovery: false
    }' '{"dimensions":[],"dimensionExclusions":[],"includeAllDimensions":false,"useSchemaDiscovery":false}'
}

# Build metrics spec from schema.json
_build_metrics_spec() {
    _build_spec "$1" '.metrics // []' '[]'
}

# Build transforms spec from schema.json
_build_transforms_spec() {
    _build_spec "$1" '{
        transforms: ((.transforms // []) | map({type: "expression", name: .name, expression: .expression})),
        filter: null
    }' '{"transforms":[],"filter":null}'
}

# Load index spec from schema.json
_load_index_spec() {
    local schema_file="$1"
    export INDEX_SPEC_BITMAP_TYPE="$(jq -r '.indexSpec.bitmapType // "roaring"' "$schema_file" 2>/dev/null || echo "roaring")"
    export INDEX_SPEC_DIMENSION_COMPRESSION="$(jq -r '.indexSpec.dimensionCompression // "lz4"' "$schema_file" 2>/dev/null || echo "lz4")"
    export INDEX_SPEC_METRIC_COMPRESSION="$(jq -r '.indexSpec.metricCompression // "lz4"' "$schema_file" 2>/dev/null || echo "lz4")"
    export INDEX_SPEC_LONG_ENCODING="$(jq -r '.indexSpec.longEncoding // "longs"' "$schema_file" 2>/dev/null || echo "longs")"
}

# Export template variables from defaults.json
_export_template_vars() {
    local defaults_file="${1:-}"
    [ -f "$defaults_file" ] && {
        # Export all tuning/task defaults from JSON
        while IFS='=' read -r key value; do
            [ -n "$key" ] && export "$key"="${!key:-$value}"
        done < <(jq -r '
            (.kafka | to_entries[] | "KAFKA_\(.key | ascii_upcase)=\(.value)"),
            (.task | to_entries[] | "TASK_\(.key | ascii_upcase)=\(.value)"),
            (.tuning | to_entries[] | "TUNING_\(.key | ascii_upcase)=\(.value)")
        ' "$defaults_file" 2>/dev/null)
    }
    
    # Set defaults for variables not in JSON
    export KAFKA_FETCH_MIN_BYTES="${KAFKA_FETCH_MIN_BYTES:-1048576}"
    export KAFKA_FETCH_MAX_WAIT_MS="${KAFKA_FETCH_MAX_WAIT_MS:-500}"
    export KAFKA_MAX_POLL_RECORDS="${KAFKA_MAX_POLL_RECORDS:-500}"
    export KAFKA_SESSION_TIMEOUT_MS="${KAFKA_SESSION_TIMEOUT_MS:-30000}"
    export KAFKA_HEARTBEAT_INTERVAL_MS="${KAFKA_HEARTBEAT_INTERVAL_MS:-3000}"
    export KAFKA_MAX_POLL_INTERVAL_MS="${KAFKA_MAX_POLL_INTERVAL_MS:-300000}"
    export KAFKA_AUTO_OFFSET_RESET="${KAFKA_AUTO_OFFSET_RESET:-latest}"
    export TASK_USE_EARLIEST_OFFSET="${TASK_USE_EARLIEST_OFFSET:-false}"
    export TASK_USE_TRANSACTION="${TASK_USE_TRANSACTION:-true}"
    export TASK_COUNT="${TASK_COUNT:-10}"
    export TASK_REPLICAS="${TASK_REPLICAS:-2}"
    export TASK_DURATION="${TASK_DURATION:-PT1H}"
    export TASK_START_DELAY="${TASK_START_DELAY:-PT5S}"
    export TASK_PERIOD="${TASK_PERIOD:-PT30S}"
    export TASK_COMPLETION_TIMEOUT="${TASK_COMPLETION_TIMEOUT:-PT1H}"
    export TASK_LATE_MESSAGE_REJECTION_PERIOD="${TASK_LATE_MESSAGE_REJECTION_PERIOD:-PT1H}"
    export TASK_POLL_TIMEOUT="${TASK_POLL_TIMEOUT:-100}"
    export TASK_MINIMUM_MESSAGE_TIME="${TASK_MINIMUM_MESSAGE_TIME:-1970-01-01T00:00:00.000Z}"
    export TUNING_MAX_ROWS_IN_MEMORY="${TUNING_MAX_ROWS_IN_MEMORY:-500000}"
    export TUNING_MAX_BYTES_IN_MEMORY="${TUNING_MAX_BYTES_IN_MEMORY:-536870912}"
    export TUNING_MAX_ROWS_PER_SEGMENT="${TUNING_MAX_ROWS_PER_SEGMENT:-5000000}"
    export TUNING_MAX_PENDING_PERSISTS="${TUNING_MAX_PENDING_PERSISTS:-2}"
    export TUNING_REPORT_PARSE_EXCEPTIONS="${TUNING_REPORT_PARSE_EXCEPTIONS:-true}"
    export TUNING_HANDOFF_CONDITION_TIMEOUT="${TUNING_HANDOFF_CONDITION_TIMEOUT:-900000}"
    export TUNING_RESET_OFFSET_AUTOMATICALLY="${TUNING_RESET_OFFSET_AUTOMATICALLY:-false}"
    export TUNING_CHAT_RETRIES="${TUNING_CHAT_RETRIES:-8}"
    export TUNING_HTTP_TIMEOUT="${TUNING_HTTP_TIMEOUT:-PT10S}"
    export TUNING_SHUTDOWN_TIMEOUT="${TUNING_SHUTDOWN_TIMEOUT:-PT80S}"
    export TUNING_OFFSET_FETCH_PERIOD="${TUNING_OFFSET_FETCH_PERIOD:-PT30S}"
    export TUNING_INTERMEDIATE_HANDOFF_PERIOD="${TUNING_INTERMEDIATE_HANDOFF_PERIOD:-P2147483647D}"
    export TUNING_LOG_PARSE_EXCEPTIONS="${TUNING_LOG_PARSE_EXCEPTIONS:-true}"
    export TUNING_MAX_PARSE_EXCEPTIONS="${TUNING_MAX_PARSE_EXCEPTIONS:-10000}"
    export TUNING_MAX_SAVED_PARSE_EXCEPTIONS="${TUNING_MAX_SAVED_PARSE_EXCEPTIONS:-100}"
    export TUNING_SKIP_SEQUENCE_NUMBER_AVAILABILITY_CHECK="${TUNING_SKIP_SEQUENCE_NUMBER_AVAILABILITY_CHECK:-false}"
    export TUNING_PARTITIONS_SPEC_TYPE="${TUNING_PARTITIONS_SPEC_TYPE:-dynamic}"
    export TUNING_SECONDARY_PARTITION_DIMENSIONS="${TUNING_SECONDARY_PARTITION_DIMENSIONS:-[]}"
    export TUNING_TARGET_ROWS_PER_SEGMENT="${TUNING_TARGET_ROWS_PER_SEGMENT:-5000000}"
    export TUNING_MAX_SPLIT_SIZE="${TUNING_MAX_SPLIT_SIZE:-1073741824}"
    export TUNING_MAX_INPUT_SEGMENT_BYTES_PER_TASK="${TUNING_MAX_INPUT_SEGMENT_BYTES_PER_TASK:-10737418240}"
}

# Build spec using template
build_spec() {
    local env="${1:-}" output="${2:-}" config_dir="${3:-}" template_dir="${4:-}"
    
    [ -z "$env" ] && log_error "Environment is required" && return 1
    export ENV="$env"
    
    local schema_file="${config_dir}/schema.json"
    [ ! -f "$schema_file" ] && log_error "Schema not found: $schema_file" && return 1
    
    local template_file="${template_dir}/supervisor-spec.json.template"
    [ ! -f "$template_file" ] && log_error "Template not found: $template_file" && return 1
    
    local defaults_file="${config_dir}/defaults.json"
    _load_index_spec "$schema_file"
    _export_template_vars "$defaults_file"
    
    local dimensions_spec metrics_spec transforms_spec
    dimensions_spec=$(_build_dimensions_spec "$schema_file") || return 1
    metrics_spec=$(_build_metrics_spec "$schema_file") || return 1
    transforms_spec=$(_build_transforms_spec "$schema_file") || return 1
    
    [ -z "$output" ] && output="$(dirname "$(dirname "$config_dir")")/druid-specs/generated/supervisor-spec-${DATASOURCE}-${env}.json"
    mkdir -p "$(dirname "$output")"
    
    local temp_file=$(mktemp)
    sed "s|__DIMENSIONS_SPEC__|$dimensions_spec|g" "$template_file" | \
        sed "s|__METRICS_SPEC__|$metrics_spec|g" | \
        sed "s|__TRANSFORM_SPEC__|$transforms_spec|g" > "$temp_file"
    
    command -v envsubst >/dev/null 2>&1 || { log_error "envsubst is required"; rm -f "$temp_file"; return 1; }
    envsubst < "$temp_file" > "$output"
    rm -f "$temp_file"
    
    command -v jq >/dev/null 2>&1 && jq empty "$output" 2>/dev/null || { log_error "Generated spec is not valid JSON"; return 1; }
    
    echo "$output"
}
