#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

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

    export ENV="$env"

    local schema="${config_dir}/schema.json"
    local template="${template_dir}/supervisor-spec.json.template"

    [[ ! -f "$schema" ]] && log_error "Schema not found: $schema" && return 1
    [[ ! -f "$template" ]] && log_error "Template not found: $template" && return 1

    _load_schema "$schema"

    output="${output:-$(dirname "$(dirname "$config_dir)")/druid-specs/generated/supervisor-spec-${DATASOURCE}-${env}.json}"
    mkdir -p "$(dirname "$output")"

    sed -e "s|__DIMENSIONS_SPEC__|${DIMENSIONS_SPEC}|g" \
        -e "s|__METRICS_SPEC__|${METRICS_SPEC}|g" \
        -e "s|__TRANSFORM_SPEC__|${TRANSFORMS_SPEC}|g" "$template" \
        | envsubst > "$output"

    jq empty "$output" || { log_error "Invalid JSON in $output"; return 1; }

    log_info "Generated: $output"
    echo "$output"
}