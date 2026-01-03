#!/usr/bin/env bash
#
# Status command - Get supervisor status from Druid
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/http-client.sh"
source "${SCRIPT_DIR}/lib/validator.sh"

execute_status() {
    local env="${1:-}"
    local config_dir="${SCRIPT_DIR}/config"
    
    log_info "Getting supervisor status for environment: $env"
    
    # Load configuration
    if ! load_config "$env" "$config_dir"; then
        return 1
    fi
    
    # Validate Druid URL
    if ! validate_url "$DRUID_URL"; then
        return 1
    fi
    
    local url="${DRUID_URL}/druid/indexer/v1/supervisor/${DATASOURCE}/status"
    log_info "Fetching status from: $url"
    
    local response
    response=$(http_request "GET" "$url") || return 1
    
    pretty_json "$response"
    return 0
}

