#!/usr/bin/env bash
#
# Prerequisites module - Check required tools
#

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

check_prerequisites() {
    local missing=()
    local optional_missing=()
    
    # Required tools
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    
    # Optional but recommended
    command -v envsubst >/dev/null 2>&1 || optional_missing+=("envsubst")
    command -v yq >/dev/null 2>&1 || optional_missing+=("yq")
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        log_error "Install with:"
        log_error "  macOS: brew install jq curl"
        log_error "  Linux: apt-get install jq curl"
        return 1
    fi
    
    if [ ${#optional_missing[@]} -gt 0 ]; then
        log_warn "Optional tools not found: ${optional_missing[*]}"
        log_warn "Install for better functionality:"
        log_warn "  macOS: brew install gettext yq"
        log_warn "  Linux: apt-get install gettext-base yq"
        log_warn "Falling back to alternative methods..."
    fi
    
    return 0
}

