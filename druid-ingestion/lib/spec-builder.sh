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

# Load index spec from schema.json (consolidated)
_load_index_spec() {
    local schema_file="$1"
    eval "$(jq -r '.indexSpec | to_entries[] | "export INDEX_SPEC_\(.key | ascii_upcase)=\"\(.value)\""' "$schema_file" 2>/dev/null || echo 'export INDEX_SPEC_BITMAP_TYPE="roaring" INDEX_SPEC_DIMENSION_COMPRESSION="lz4" INDEX_SPEC_METRIC_COMPRESSION="lz4" INDEX_SPEC_LONG_ENCODING="longs"')"
}

# Export template variables from defaults.json
_export_template_vars() {
    local defaults_file="${1:-}"
    [ ! -f "$defaults_file" ] && return
    
    # Export kafka.* as KAFKA_*
    jq -r '.kafka | to_entries[] | "export KAFKA_\(.key | ascii_upcase | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)") | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)"))=\"\(.value)\""' "$defaults_file" 2>/dev/null | while IFS='=' read -r key value; do
        [ -n "$key" ] && export "$key"="${!key:-$value}"
    done
    
    # Export task.* as TASK_*
    jq -r '.task | to_entries[] | "export TASK_\(.key | ascii_upcase | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)") | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)"))=\"\(.value)\""' "$defaults_file" 2>/dev/null | while IFS='=' read -r key value; do
        [ -n "$key" ] && export "$key"="${!key:-$value}"
    done
    
    # Export tuning.* as TUNING_*
    jq -r '.tuning | to_entries[] | "export TUNING_\(.key | ascii_upcase | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)") | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)"))=\"\(.value)\""' "$defaults_file" 2>/dev/null | while IFS='=' read -r key value; do
        [ -n "$key" ] && export "$key"="${!key:-$value}"
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
