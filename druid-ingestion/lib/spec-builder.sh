#!/usr/bin/env bash
#
# Spec Builder - Simplified (schema from schema.json, config from .env)
#

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Load schema sections from schema.json
_load_schema() {
    local schema_file="$1"
    
    # Dimensions spec
    export DIMENSIONS_SPEC=$(jq -c '{
        dimensions: (.dimensions // []),
        dimensionExclusions: ["settlement_ts", "settlement_entry_ts", "acceptance_ts", "payee_access_manager_id"],
        includeAllDimensions: false,
        useSchemaDiscovery: false
    }' "$schema_file" 2>/dev/null || echo '{"dimensions":[],"dimensionExclusions":[],"includeAllDimensions":false,"useSchemaDiscovery":false}')
    
    # Metrics spec
    export METRICS_SPEC=$(jq -c '.metrics // []' "$schema_file" 2>/dev/null || echo '[]')
    
    # Transforms spec
    export TRANSFORMS_SPEC=$(jq -c '{
        transforms: ((.transforms // []) | map({type: "expression", name: .name, expression: .expression})),
        filter: null
    }' "$schema_file" 2>/dev/null || echo '{"transforms":[],"filter":null}')
    
    # Index spec (from schema.json or use env vars if not present)
    eval "$(jq -r '.indexSpec | to_entries[] | "export INDEX_SPEC_\(.key | ascii_upcase)=\"\(.value)\""' "$schema_file" 2>/dev/null || echo '')"
}

# Build spec using template (schema from schema.json, config from .env)
build_spec() {
    local env="${1:-}" output="${2:-}" config_dir="${3:-}" template_dir="${4:-}"
    
    [ -z "$env" ] && log_error "Environment is required" && return 1
    export ENV="$env"
    
    local schema_file="${config_dir}/schema.json"
    [ ! -f "$schema_file" ] && log_error "Schema not found: $schema_file" && return 1
    
    local template_file="${template_dir}/supervisor-spec.json.template"
    [ ! -f "$template_file" ] && log_error "Template not found: $template_file" && return 1
    
    # Load schema sections
    _load_schema "$schema_file"
    
    [ -z "$output" ] && output="$(dirname "$(dirname "$config_dir")")/druid-specs/generated/supervisor-spec-${DATASOURCE}-${env}.json"
    mkdir -p "$(dirname "$output")"
    
    # Replace schema placeholders with sed, then substitute env vars with envsubst
    local temp_file=$(mktemp)
    sed -e "s|__DIMENSIONS_SPEC__|$DIMENSIONS_SPEC|g" \
        -e "s|__METRICS_SPEC__|$METRICS_SPEC|g" \
        -e "s|__TRANSFORM_SPEC__|$TRANSFORMS_SPEC|g" "$template_file" > "$temp_file"
    
    command -v envsubst >/dev/null 2>&1 || { log_error "envsubst is required"; rm -f "$temp_file"; return 1; }
    envsubst < "$temp_file" > "$output"
    rm -f "$temp_file"
    
    command -v jq >/dev/null 2>&1 && jq empty "$output" 2>/dev/null || { log_error "Invalid JSON"; return 1; }
    echo "$output"
}
