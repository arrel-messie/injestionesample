#!/bin/bash
# common.sh - Common functions for Druid ingestion scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_ROOT="$(dirname "$SCRIPT_DIR")"

# Validate environment
validate_environment() {
    local env=$1
    if [[ ! "$env" =~ ^(dev|staging|prod)$ ]]; then
        echo "ERROR: Invalid environment: $env (use: dev, staging, prod)" >&2
        exit 1
    fi
}

# Check if file exists
check_file() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo "ERROR: File not found: $file" >&2
        exit 1
    fi
}

# Check if directory exists
check_dir() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        echo "ERROR: Directory not found: $dir" >&2
        exit 1
    fi
}

# Check if command exists
check_command() {
    local cmd=$1
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Required command '$cmd' not found. Please install it." >&2
        exit 1
    fi
}

# Load and validate config file
load_config() {
    local env=$1
    local config_file="$MODULE_ROOT/config/${env}.env"
    check_file "$config_file"
    source "$config_file"
}

# Validate required variables
validate_vars() {
    local config_file=$1
    shift
    local vars=("$@")
    for var in "${vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            echo "ERROR: Required variable $var is not set in $config_file" >&2
            exit 1
        fi
    done
}

