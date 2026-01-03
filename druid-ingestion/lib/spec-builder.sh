#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

_load_config() {
    local env="$1" config_dir="$2"
    if [[ ! "$env" =~ ^(dev|interim|prod)$ ]]; then
        log_error "Invalid environment: $env"
        return 1
    fi
    
    local env_file="${config_dir}/${env}.env"
    if [[ ! -f "$env_file" ]]; then
        log_error "Config not found: $env_file"
        return 1
    fi
    
    set -a
    source "$env_file" || { set +a; return 1; }
    set +a
    
    local required=("DRUID_URL" "DATASOURCE" "KAFKA_BOOTSTRAP_SERVERS" "KAFKA_TOPIC")
    for var in "${required[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Missing: $var"
            return 1
        fi
    done
    if [[ ! "${DRUID_URL}" =~ ^https?:// ]]; then
        log_error "Invalid DRUID_URL"
        return 1
    fi
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
    
    if ! _load_config "$env" "$config_dir"; then
        return 1
    fi
    
    local schema="${config_dir}/schema.json" template="${template_dir}/supervisor-spec.json.template"
    if [[ ! -f "$schema" ]]; then
        log_error "Schema not found"
        return 1
    fi
    if [[ ! -f "$template" ]]; then
        log_error "Template not found"
        return 1
    fi
    
    _load_schema "$schema"
    
    local script_dir="${SCRIPT_DIR:-$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")")}"
    output="${output:-${script_dir}/druid-specs/generated/supervisor-spec-${DATASOURCE}.json}"
    mkdir -p "$(dirname "$output")"
    
    local tmp="${output}.tmp"
    if ! sed -e "s|__DIMENSIONS_SPEC__|${DIMENSIONS_SPEC}|g" \
        -e "s|__METRICS_SPEC__|${METRICS_SPEC}|g" \
        -e "s|__TRANSFORM_SPEC__|${TRANSFORMS_SPEC}|g" "$template" \
        | envsubst > "$tmp"; then
        log_error "Generation failed"
        return 1
    fi
    
    if ! jq empty "$tmp" 2>/dev/null; then
        log_error "Invalid JSON"
        jq . "$tmp" 2>&1 | head -20 >&2
        rm -f "$tmp"
        return 1
    fi
    
    mv "$tmp" "$output"
    log_info "Generated: $output"
    echo "$output"
}
