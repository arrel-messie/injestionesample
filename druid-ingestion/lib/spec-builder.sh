#!/usr/bin/env bash
#
# Spec Builder - Optimized version using template
#

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/yaml-helper.sh"

# Build dimensions spec from schema.yml
_build_dimensions_spec() {
    local schema_file="$1"
    local json=$(yaml_to_json "$schema_file")
    echo "$json" | jq -c '{
        dimensions: (.dimensions // []),
        dimensionExclusions: ["settlement_ts", "settlement_entry_ts", "acceptance_ts", "payee_access_manager_id"],
        includeAllDimensions: false,
        useSchemaDiscovery: false
    }' 2>/dev/null || echo '{"dimensions":[],"dimensionExclusions":[],"includeAllDimensions":false,"useSchemaDiscovery":false}'
}

# Build metrics spec from schema.yml
_build_metrics_spec() {
    local schema_file="$1"
    local json=$(yaml_to_json "$schema_file")
    echo "$json" | jq -c '.metrics // []' 2>/dev/null || echo '[]'
}

# Build transforms spec from schema.yml
_build_transforms_spec() {
    local schema_file="$1"
    local json=$(yaml_to_json "$schema_file")
    echo "$json" | jq -c '{
        transforms: ((.transforms // []) | map({type: "expression", name: .name, expression: .expression})),
        filter: null
    }' 2>/dev/null || echo '{"transforms":[],"filter":null}'
}

# Load index spec from schema.yml
_load_index_spec() {
    local schema_file="$1"
    yaml_export "$schema_file" ".indexSpec.bitmapType" "INDEX_SPEC_BITMAP_TYPE" "roaring"
    yaml_export "$schema_file" ".indexSpec.dimensionCompression" "INDEX_SPEC_DIMENSION_COMPRESSION" "lz4"
    yaml_export "$schema_file" ".indexSpec.metricCompression" "INDEX_SPEC_METRIC_COMPRESSION" "lz4"
    yaml_export "$schema_file" ".indexSpec.longEncoding" "INDEX_SPEC_LONG_ENCODING" "longs"
}

# Export all template variables at once
_export_template_vars() {
    # Variables are already exported by load_config, just ensure they exist
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
    
    local schema_file="${config_dir}/schema.yml"
    [ ! -f "$schema_file" ] && log_error "Schema not found: $schema_file" && return 1
    
    local template_file="${template_dir}/supervisor-spec.json.template"
    [ ! -f "$template_file" ] && log_error "Template not found: $template_file" && return 1
    
    _load_index_spec "$schema_file"
    _export_template_vars
    
    local dimensions_spec metrics_spec transforms_spec
    dimensions_spec=$(_build_dimensions_spec "$schema_file") || return 1
    metrics_spec=$(_build_metrics_spec "$schema_file") || return 1
    transforms_spec=$(_build_transforms_spec "$schema_file") || return 1
    
    [ -z "$output" ] && output="$(dirname "$(dirname "$config_dir")")/druid-specs/generated/supervisor-spec-${DATASOURCE}-${env}.json"
    mkdir -p "$(dirname "$output")"
    
    log_info "Building supervisor spec: $output"
    
    local temp_file=$(mktemp)
    sed "s|__DIMENSIONS_SPEC__|$dimensions_spec|g" "$template_file" | \
        sed "s|__METRICS_SPEC__|$metrics_spec|g" | \
        sed "s|__TRANSFORM_SPEC__|$transforms_spec|g" > "$temp_file"
    
    command -v envsubst >/dev/null 2>&1 || { log_error "envsubst is required"; rm -f "$temp_file"; return 1; }
    envsubst < "$temp_file" > "$output"
    rm -f "$temp_file"
    
    command -v jq >/dev/null 2>&1 && jq empty "$output" 2>/dev/null || { log_error "Generated spec is not valid JSON"; return 1; }
    
    log_info "Supervisor spec built successfully: $output"
    echo "$output"
}

