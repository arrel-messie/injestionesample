#!/usr/bin/env bash
#
# Build command - Build supervisor specification JSON
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/spec-builder.sh"

execute_build() {
    local env="${1:-}"
    local output="${2:-}"
    local config_dir="${SCRIPT_DIR}/config"
    local template_dir="${SCRIPT_DIR}/templates"
    
    log_info "Building supervisor spec for environment: $env"
    
    # Load configuration
    if ! load_config "$env" "$config_dir"; then
        return 1
    fi
    
    # Build spec
    if ! build_spec "$env" "$output" "$config_dir" "$template_dir"; then
        return 1
    fi
    
    return 0
}

