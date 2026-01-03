#!/usr/bin/env bash
#
# Deploy command - Deploy supervisor to Druid Overlord
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/spec-builder.sh"
source "${SCRIPT_DIR}/lib/http-client.sh"
source "${SCRIPT_DIR}/lib/validator.sh"

execute_deploy() {
    local env="${1:-}"
    local config_dir="${SCRIPT_DIR}/config"
    local template_dir="${SCRIPT_DIR}/templates"
    local specs_dir="${SCRIPT_DIR}/druid-specs/generated"
    
    log_info "Deploying supervisor for environment: $env"
    
    # Load configuration
    if ! load_config "$env" "$config_dir"; then
        return 1
    fi
    
    # Validate Druid URL
    if ! validate_url "$DRUID_URL"; then
        return 1
    fi
    
    # Build spec if not exists
    local spec_file="${specs_dir}/supervisor-spec-${DATASOURCE}-${env}.json"
    if [ ! -f "$spec_file" ]; then
        log_info "Spec file not found, building it first..."
        if ! build_spec "$env" "$spec_file" "$config_dir" "$template_dir"; then
            return 1
        fi
    fi
    
    # Deploy to Druid
    local url="${DRUID_URL}/druid/indexer/v1/supervisor"
    log_info "Posting spec to: $url"
    
    local response
    response=$(http_request "POST" "$url" "$spec_file") || return 1
    
    log_info "Supervisor deployed successfully for datasource: $DATASOURCE"
    pretty_json "$response"
    return 0
}

