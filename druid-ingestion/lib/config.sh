#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

load_config() {
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
