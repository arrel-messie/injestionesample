#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

_load_config() {
    local env="$1" config_dir="$2"
    [[ ! "$env" =~ ^(dev|staging|prod|test)$ ]] && log_error "Invalid environment: $env" && return 1
    
    local env_file="${config_dir}/${env}.env"
    [[ ! -f "$env_file" ]] && log_error "Config not found: $env_file" && return 1
    
    set -a && source "$env_file" && set +a
    
    local required=("DRUID_URL" "DATASOURCE" "KAFKA_BOOTSTRAP_SERVERS" "KAFKA_TOPIC")
    for var in "${required[@]}"; do
        [[ -z "${!var:-}" ]] && log_error "Missing: $var" && return 1
    done
    [[ ! "${DRUID_URL}" =~ ^https?:// ]] && log_error "Invalid DRUID_URL" && return 1
    export ENV="$env"
}

_load_schema() {
    local schema="$1"
    DIMENSIONS_SPEC=$(jq -c '{dimensions: (.dimensions // []), dimensionExclusions: (.dimensionsSpec.dimensionExclusions // []), includeAllDimensions: (.dimensionsSpec.includeAllDimensions // false), useSchemaDiscovery: (.dimensionsSpec.useSchemaDiscovery // false)}' "$schema")
    METRICS_SPEC=$(jq -c '.metrics // []' "$schema")
    TRANSFORMS_SPEC=$(jq -c '{transforms: ((.transforms // []) | map({type: "expression", name, expression})), filter: null}' "$schema")
    eval "$(jq -r '.indexSpec // {} | to_entries[] | "export INDEX_SPEC_\(.key | ascii_upcase)=\(.value | @sh)"' "$schema")"
    export DIMENSIONS_SPEC METRICS_SPEC TRANSFORMS_SPEC
}

build_spec() {
    local env="$1" output="$2" config_dir="$3" template_dir="$4"
    
    _load_config "$env" "$config_dir" || return 1
    
    local schema="${config_dir}/schema.json" template="${template_dir}/supervisor-spec.json.template"
    [[ ! -f "$schema" ]] && log_error "Schema not found" && return 1
    [[ ! -f "$template" ]] && log_error "Template not found" && return 1
    
    _load_schema "$schema"
    
    output="${output:-$(dirname "$(dirname "$config_dir")")/druid-specs/generated/supervisor-spec-${DATASOURCE}-${env}.json}"
    mkdir -p "$(dirname "$output")"
    
    local tmp="${output}.tmp"
    sed -e "s|__DIMENSIONS_SPEC__|${DIMENSIONS_SPEC}|g" \
        -e "s|__METRICS_SPEC__|${METRICS_SPEC}|g" \
        -e "s|__TRANSFORM_SPEC__|${TRANSFORMS_SPEC}|g" "$template" \
        | envsubst > "$tmp" || { log_error "Generation failed"; return 1; }
    
    jq empty "$tmp" 2>/dev/null || {
        log_error "Invalid JSON"
        jq . "$tmp" 2>&1 | head -20 >&2
        rm -f "$tmp"
        return 1
    }
    
    mv "$tmp" "$output"
    log_info "Generated: $output"
    echo "$output"
}
