#!/usr/bin/env bash
#
# Spec Builder - Version Simplifiée utilisant le template
#

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Build dimensions spec from schema.yml
_build_dimensions_spec() {
    local schema_file="$1"
    if command -v yq >/dev/null 2>&1; then
        yq eval -o=json "$schema_file" | jq -c '{
            dimensions: (.dimensions // []),
            dimensionExclusions: ["settlement_ts", "settlement_entry_ts", "acceptance_ts", "payee_access_manager_id"],
            includeAllDimensions: false,
            useSchemaDiscovery: false
        }'
    else
        python3 -c "
import yaml, json
with open('$schema_file') as f:
    s = yaml.safe_load(f)
    print(json.dumps({
        'dimensions': s.get('dimensions', []),
        'dimensionExclusions': ['settlement_ts', 'settlement_entry_ts', 'acceptance_ts', 'payee_access_manager_id'],
        'includeAllDimensions': False,
        'useSchemaDiscovery': False
    }, separators=(',', ':')))
"
    fi
}

# Build metrics spec from schema.yml
_build_metrics_spec() {
    local schema_file="$1"
    if command -v yq >/dev/null 2>&1; then
        yq eval -o=json "$schema_file" | jq -c '.metrics // []'
    else
        python3 -c "import yaml, json; print(json.dumps(yaml.safe_load(open('$schema_file')).get('metrics', []), separators=(',', ':')))"
    fi
}

# Build transforms spec from schema.yml
_build_transforms_spec() {
    local schema_file="$1"
    if command -v yq >/dev/null 2>&1; then
        yq eval -o=json "$schema_file" | jq -c '{
            transforms: ((.transforms // []) | map({type: "expression", name: .name, expression: .expression})),
            filter: null
        }'
    else
        python3 -c "
import yaml, json
with open('$schema_file') as f:
    s = yaml.safe_load(f)
    print(json.dumps({
        'transforms': [{'type': 'expression', 'name': t['name'], 'expression': t['expression']} for t in s.get('transforms', [])],
        'filter': None
    }, separators=(',', ':')))
"
    fi
}

# Load index spec from schema.yml
_load_index_spec() {
    local schema_file="$1"
    if command -v yq >/dev/null 2>&1; then
        export INDEX_SPEC_BITMAP_TYPE="$(yq eval '.indexSpec.bitmapType' "$schema_file" 2>/dev/null || echo "roaring")"
        export INDEX_SPEC_DIMENSION_COMPRESSION="$(yq eval '.indexSpec.dimensionCompression' "$schema_file" 2>/dev/null || echo "lz4")"
        export INDEX_SPEC_METRIC_COMPRESSION="$(yq eval '.indexSpec.metricCompression' "$schema_file" 2>/dev/null || echo "lz4")"
        export INDEX_SPEC_LONG_ENCODING="$(yq eval '.indexSpec.longEncoding' "$schema_file" 2>/dev/null || echo "longs")"
    else
        python3 -c "
import yaml, os
s = yaml.safe_load(open('$schema_file'))
idx = s.get('indexSpec', {})
os.environ['INDEX_SPEC_BITMAP_TYPE'] = idx.get('bitmapType', 'roaring')
os.environ['INDEX_SPEC_DIMENSION_COMPRESSION'] = idx.get('dimensionCompression', 'lz4')
os.environ['INDEX_SPEC_METRIC_COMPRESSION'] = idx.get('metricCompression', 'lz4')
os.environ['INDEX_SPEC_LONG_ENCODING'] = idx.get('longEncoding', 'longs')
" && source <(python3 -c "
import yaml, os
s = yaml.safe_load(open('$schema_file'))
idx = s.get('indexSpec', {})
print(f\"export INDEX_SPEC_BITMAP_TYPE={idx.get('bitmapType', 'roaring')}\")
print(f\"export INDEX_SPEC_DIMENSION_COMPRESSION={idx.get('dimensionCompression', 'lz4')}\")
print(f\"export INDEX_SPEC_METRIC_COMPRESSION={idx.get('metricCompression', 'lz4')}\")
print(f\"export INDEX_SPEC_LONG_ENCODING={idx.get('longEncoding', 'longs')}\")
")
    fi
}

# Build spec using template (SIMPLIFIED)
build_spec() {
    local env="${1:-}" output="${2:-}" config_dir="${3:-}" template_dir="${4:-}"
    
    [ -z "$env" ] && log_error "Environment is required" && return 1
    export ENV="$env"
    
    local schema_file="${config_dir}/schema.yml"
    [ ! -f "$schema_file" ] && log_error "Schema not found: $schema_file" && return 1
    
    local template_file="${template_dir}/supervisor-spec.json.template"
    [ ! -f "$template_file" ] && log_error "Template not found: $template_file" && return 1
    
    # Load index spec
    _load_index_spec "$schema_file"
    
    # Build schema components (JSON strings)
    local dimensions_spec metrics_spec transforms_spec
    dimensions_spec=$(_build_dimensions_spec "$schema_file") || return 1
    metrics_spec=$(_build_metrics_spec "$schema_file") || return 1
    transforms_spec=$(_build_transforms_spec "$schema_file") || return 1
    
    # Determine output
    [ -z "$output" ] && output="$(dirname "$(dirname "$config_dir")")/druid-specs/generated/supervisor-spec-${DATASOURCE}-${env}.json"
    mkdir -p "$(dirname "$output")"
    
    log_info "Building supervisor spec: $output"
    
    # Use template with substitution
    local temp_file
    temp_file=$(mktemp)
    
    # Replace JSON placeholders first (before envsubst)
    # These are complex JSON objects that need to be inserted as-is
    sed "s|__DIMENSIONS_SPEC__|$dimensions_spec|g" "$template_file" | \
    sed "s|__METRICS_SPEC__|$metrics_spec|g" | \
    sed "s|__TRANSFORM_SPEC__|$transforms_spec|g" > "$temp_file"
    
    # Substitute environment variables using envsubst
    # envsubst handles ${VAR} and ${VAR:-default} syntax
    if command -v envsubst >/dev/null 2>&1; then
        # Export all variables that might be used in template
        export KAFKA_BOOTSTRAP_SERVERS KAFKA_SECURITY_PROTOCOL KAFKA_SASL_MECHANISM
        export KAFKA_SASL_JAAS_CONFIG KAFKA_SSL_ENDPOINT_ID DATASOURCE ENV
        export KAFKA_TOPIC PROTO_DESCRIPTOR_PATH PROTO_MESSAGE_TYPE
        export DRUID_TIMESTAMP_COLUMN DRUID_TIMESTAMP_FORMAT
        export GRANULARITY_SEGMENT GRANULARITY_QUERY GRANULARITY_ROLLUP
        export KAFKA_FETCH_MIN_BYTES KAFKA_FETCH_MAX_WAIT_MS KAFKA_MAX_POLL_RECORDS
        export KAFKA_SESSION_TIMEOUT_MS KAFKA_HEARTBEAT_INTERVAL_MS KAFKA_MAX_POLL_INTERVAL_MS
        export KAFKA_AUTO_OFFSET_RESET
        export TASK_USE_EARLIEST_OFFSET TASK_USE_TRANSACTION TASK_COUNT TASK_REPLICAS
        export TASK_DURATION TASK_START_DELAY TASK_PERIOD TASK_COMPLETION_TIMEOUT
        export TASK_LATE_MESSAGE_REJECTION_PERIOD TASK_POLL_TIMEOUT TASK_MINIMUM_MESSAGE_TIME
        export TUNING_MAX_ROWS_IN_MEMORY TUNING_MAX_BYTES_IN_MEMORY TUNING_MAX_ROWS_PER_SEGMENT
        export TUNING_MAX_PENDING_PERSISTS TUNING_REPORT_PARSE_EXCEPTIONS
        export TUNING_HANDOFF_CONDITION_TIMEOUT TUNING_RESET_OFFSET_AUTOMATICALLY
        export TUNING_CHAT_RETRIES TUNING_HTTP_TIMEOUT TUNING_SHUTDOWN_TIMEOUT
        export TUNING_OFFSET_FETCH_PERIOD TUNING_INTERMEDIATE_HANDOFF_PERIOD
        export TUNING_LOG_PARSE_EXCEPTIONS TUNING_MAX_PARSE_EXCEPTIONS
        export TUNING_MAX_SAVED_PARSE_EXCEPTIONS TUNING_SKIP_SEQUENCE_NUMBER_AVAILABILITY_CHECK
        export TUNING_PARTITIONS_SPEC_TYPE TUNING_SECONDARY_PARTITION_DIMENSIONS
        export TUNING_TARGET_ROWS_PER_SEGMENT TUNING_MAX_SPLIT_SIZE
        export TUNING_MAX_INPUT_SEGMENT_BYTES_PER_TASK
        
        envsubst < "$temp_file" > "$output"
    else
        log_error "envsubst is required for template substitution"
        rm -f "$temp_file"
        return 1
    fi
    
    rm -f "$temp_file"
    
    # Validate JSON
    if command -v jq >/dev/null 2>&1; then
        jq empty "$output" 2>/dev/null || { log_error "Generated spec is not valid JSON"; return 1; }
    fi
    
    log_info "Supervisor spec built successfully: $output"
    echo "$output"
}

