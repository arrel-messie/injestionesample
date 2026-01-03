#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

_load_config() {
    local env="${1:-}" config_dir="${2:-}"
    
    [ -z "$env" ] && log_error "Environment is required" && return 1
    [[ ! "$env" =~ ^(dev|staging|prod|test)$ ]] && log_error "Invalid environment: $env" && return 1
    [ -z "$config_dir" ] && config_dir="$(dirname "${BASH_SOURCE[0]}")/../config"
    
    local env_file="${config_dir}/${env}.env"
    [ ! -f "$env_file" ] && log_error "Config file not found: $env_file" && return 1
    
    set -a
    source "$env_file"
    set +a
    
    local required_vars=("DRUID_URL" "DATASOURCE" "KAFKA_BOOTSTRAP_SERVERS" "KAFKA_TOPIC")
    for var in "${required_vars[@]}"; do
        [[ -z "${!var:-}" ]] && log_error "Required variable not set: $var" && return 1
    done
    
    [[ ! "${DRUID_URL}" =~ ^https?:// ]] && {
        log_error "Invalid DRUID_URL: ${DRUID_URL}"
        return 1
    }
    export ENV="$env"
}

_load_schema() {
    local schema="$1"

    DIMENSIONS_SPEC=$(jq -c '{
        dimensions: (.dimensions // []),
        dimensionExclusions: (.dimensionsSpec.dimensionExclusions // []),
        includeAllDimensions: (.dimensionsSpec.includeAllDimensions // false),
        useSchemaDiscovery: (.dimensionsSpec.useSchemaDiscovery // false)
    }' "$schema")

    METRICS_SPEC=$(jq -c '.metrics // []' "$schema")

    TRANSFORMS_SPEC=$(jq -c '{
        transforms: ((.transforms // []) | map({type: "expression", name, expression})),
        filter: null
    }' "$schema")

    eval "$(jq -r '.indexSpec // {} | to_entries[] |
        "export INDEX_SPEC_\(.key | ascii_upcase)=\(.value | @sh)"' "$schema")"

    export DIMENSIONS_SPEC METRICS_SPEC TRANSFORMS_SPEC
}

build_spec() {
    local env="${1:?Environment required}"
    local output="${2:-}"
    local config_dir="${3:?Config directory required}"
    local template_dir="${4:?Template directory required}"

    _load_config "$env" "$config_dir" || return 1

    local schema="${config_dir}/schema.json"
    local template="${template_dir}/supervisor-spec.json.template"

    [[ ! -f "$schema" ]] && log_error "Schema not found: $schema" && return 1
    [[ ! -f "$template" ]] && log_error "Template not found: $template" && return 1

    _load_schema "$schema"

    output="${output:-$(dirname "$(dirname "$config_dir")")/druid-specs/generated/supervisor-spec-${DATASOURCE}-${env}.json}"
    mkdir -p "$(dirname "$output")" || { log_error "Failed to create output directory"; return 1; }

    local temp_output="${output}.tmp"
    
    sed -e "s|__DIMENSIONS_SPEC__|${DIMENSIONS_SPEC}|g" \
        -e "s|__METRICS_SPEC__|${METRICS_SPEC}|g" \
        -e "s|__TRANSFORM_SPEC__|${TRANSFORMS_SPEC}|g" "$template" \
        | envsubst > "$temp_output" || { log_error "Failed to generate spec"; return 1; }

    jq empty "$temp_output" 2>/dev/null || { 
        log_error "Invalid JSON generated. Checking for issues..."
        jq . "$temp_output" 2>&1 | head -20 >&2
        rm -f "$temp_output"
        return 1
    }

    mv "$temp_output" "$output" || { log_error "Failed to move output file"; return 1; }

    log_info "Generated: $output"
    echo "$output"
}
