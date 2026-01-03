#!/usr/bin/env bash
#
# Validator module - Input validation functions
#

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

validate_environment() {
    local env="${1:-}"
    
    if [ -z "$env" ]; then
        log_error "Environment (-e) is required. Use: dev, staging, or prod"
        return 1
    fi
    
    if [[ ! "$env" =~ ^(dev|staging|prod|test)$ ]]; then
        log_error "Invalid environment: $env. Must be one of: dev, staging, prod, test"
        return 1
    fi
    
    return 0
}

validate_url() {
    local url="${1:-}"
    
    if [ -z "$url" ]; then
        log_error "URL is required"
        return 1
    fi
    
    if [[ ! "$url" =~ ^https?:// ]]; then
        log_error "Invalid URL: $url (must start with http:// or https://)"
        return 1
    fi
    
    return 0
}

validate_file_exists() {
    local file="${1:-}"
    local description="${2:-File}"
    
    if [ -z "$file" ]; then
        log_error "${description} path is required"
        return 1
    fi
    
    if [ ! -f "$file" ]; then
        log_error "${description} not found: $file"
        return 1
    fi
    
    return 0
}

