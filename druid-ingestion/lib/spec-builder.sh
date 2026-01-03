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
    sed "s|__DIMENSIONS_SPEC__|$dimensions_spec|g" "$template_file" | \
    sed "s|__METRICS_SPEC__|$metrics_spec|g" | \
    sed "s|__TRANSFORM_SPEC__|$transforms_spec|g" > "$temp_file"
    
    # Substitute environment variables
    if command -v envsubst >/dev/null 2>&1; then
        envsubst < "$temp_file" > "$output"
    else
        # Fallback: manual substitution for critical vars
        sed -e "s|\${KAFKA_BOOTSTRAP_SERVERS}|${KAFKA_BOOTSTRAP_SERVERS}|g" \
            -e "s|\${DATASOURCE}|${DATASOURCE}|g" \
            -e "s|\${ENV}|${ENV}|g" \
            -e "s|\${KAFKA_TOPIC}|${KAFKA_TOPIC}|g" \
            -e "s|\${PROTO_DESCRIPTOR_PATH}|${PROTO_DESCRIPTOR_PATH}|g" \
            -e "s|\${PROTO_MESSAGE_TYPE}|${PROTO_MESSAGE_TYPE}|g" \
            -e "s|\${DRUID_TIMESTAMP_COLUMN}|${DRUID_TIMESTAMP_COLUMN}|g" \
            -e "s|\${DRUID_TIMESTAMP_FORMAT}|${DRUID_TIMESTAMP_FORMAT}|g" \
            -e "s|\${GRANULARITY_SEGMENT}|${GRANULARITY_SEGMENT}|g" \
            -e "s|\${GRANULARITY_QUERY}|${GRANULARITY_QUERY}|g" \
            -e "s|\${GRANULARITY_ROLLUP}|${GRANULARITY_ROLLUP}|g" \
            "$temp_file" > "$output"
    fi
    
    rm -f "$temp_file"
    
    # Validate JSON
    if command -v jq >/dev/null 2>&1; then
        jq empty "$output" 2>/dev/null || { log_error "Generated spec is not valid JSON"; return 1; }
    fi
    
    log_info "Supervisor spec built successfully: $output"
    echo "$output"
}

