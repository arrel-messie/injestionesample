#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_ROOT="$(dirname "$SCRIPT_DIR")"

validate_environment() {
    [[ "$1" =~ ^(dev|staging|prod)$ ]] || {
        echo "ERROR: Invalid environment: $1 (use: dev, staging, prod)" >&2
        exit 1
    }
}

check_file() {
    [ -f "$1" ] || { echo "ERROR: File not found: $1" >&2; exit 1; }
}

check_dir() {
    [ -d "$1" ] || { echo "ERROR: Directory not found: $1" >&2; exit 1; }
}

check_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: Command not found: $1" >&2
        exit 1
    }
}

load_config() {
    local config_file="$MODULE_ROOT/config/${1}.env"
    check_file "$config_file"
    source "$config_file"
}

validate_vars() {
    local config_file=$1
    shift
    for var in "$@"; do
        if [ -z "${!var:-}" ]; then
            echo "ERROR: Variable not set: $var in $config_file" >&2
            exit 1
        fi
    done
}

