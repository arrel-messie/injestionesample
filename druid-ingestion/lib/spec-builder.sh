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

# Export template variables with defaults (using mapping table)
_export_template_vars() {
    local vars=(
        "KAFKA_FETCH_MIN_BYTES:1048576" "KAFKA_FETCH_MAX_WAIT_MS:500" "KAFKA_MAX_POLL_RECORDS:500"
        "KAFKA_SESSION_TIMEOUT_MS:30000" "KAFKA_HEARTBEAT_INTERVAL_MS:3000" "KAFKA_MAX_POLL_INTERVAL_MS:300000"
        "KAFKA_AUTO_OFFSET_RESET:latest" "TASK_USE_EARLIEST_OFFSET:false" "TASK_USE_TRANSACTION:true"
        "TASK_COUNT:10" "TASK_REPLICAS:2" "TASK_DURATION:PT1H" "TASK_START_DELAY:PT5S" "TASK_PERIOD:PT30S"
        "TASK_COMPLETION_TIMEOUT:PT1H" "TASK_LATE_MESSAGE_REJECTION_PERIOD:PT1H" "TASK_POLL_TIMEOUT:100"
        "TASK_MINIMUM_MESSAGE_TIME:1970-01-01T00:00:00.000Z" "TUNING_MAX_ROWS_IN_MEMORY:500000"
        "TUNING_MAX_BYTES_IN_MEMORY:536870912" "TUNING_MAX_ROWS_PER_SEGMENT:5000000" "TUNING_MAX_PENDING_PERSISTS:2"
        "TUNING_REPORT_PARSE_EXCEPTIONS:true" "TUNING_HANDOFF_CONDITION_TIMEOUT:900000"
        "TUNING_RESET_OFFSET_AUTOMATICALLY:false" "TUNING_CHAT_RETRIES:8" "TUNING_HTTP_TIMEOUT:PT10S"
        "TUNING_SHUTDOWN_TIMEOUT:PT80S" "TUNING_OFFSET_FETCH_PERIOD:PT30S" "TUNING_INTERMEDIATE_HANDOFF_PERIOD:P2147483647D"
        "TUNING_LOG_PARSE_EXCEPTIONS:true" "TUNING_MAX_PARSE_EXCEPTIONS:10000" "TUNING_MAX_SAVED_PARSE_EXCEPTIONS:100"
        "TUNING_SKIP_SEQUENCE_NUMBER_AVAILABILITY_CHECK:false" "TUNING_PARTITIONS_SPEC_TYPE:dynamic"
        "TUNING_SECONDARY_PARTITION_DIMENSIONS:[]" "TUNING_TARGET_ROWS_PER_SEGMENT:5000000"
        "TUNING_MAX_SPLIT_SIZE:1073741824" "TUNING_MAX_INPUT_SEGMENT_BYTES_PER_TASK:10737418240"
    )
    local var default
    for entry in "${vars[@]}"; do
        IFS=':' read -r var default <<< "$entry"
        export "$var"="${!var:-$default}"
    done
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
    sed -e "s|__DIMENSIONS_SPEC__|$dimensions_spec|g" \
        -e "s|__METRICS_SPEC__|$metrics_spec|g" \
        -e "s|__TRANSFORM_SPEC__|$transforms_spec|g" "$template_file" > "$temp_file"
    
    command -v envsubst >/dev/null 2>&1 || { log_error "envsubst is required"; rm -f "$temp_file"; return 1; }
    envsubst < "$temp_file" > "$output"
    rm -f "$temp_file"
    
    command -v jq >/dev/null 2>&1 && jq empty "$output" 2>/dev/null || { log_error "Invalid JSON"; return 1; }
    echo "$output"
}
