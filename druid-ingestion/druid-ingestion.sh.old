#!/usr/bin/env bash
#
# Druid Ingestion Manager - Shell Solution (Simplified)
# Simple, maintainable shell script for managing Druid supervisor deployments
#
# Usage:
#   ./druid-ingestion.sh build -e dev
#   ./druid-ingestion.sh deploy -e dev
#   ./druid-ingestion.sh status -e dev
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
SPECS_DIR="${SCRIPT_DIR}/druid-specs/generated"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Logging
log_info() { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
error_exit() { log_error "$1"; exit "${2:-1}"; }

# Check prerequisites
check_prerequisites() {
    local missing=()
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    
    if [ ${#missing[@]} -gt 0 ]; then
        error_exit "Missing required tools: ${missing[*]}. Install with: brew install jq curl (macOS) or apt-get install jq curl (Linux)"
    fi
}

# Validation (moved to config.sh)
validate_file_exists() {
    [ -z "$1" ] && log_error "File path is required" && return 1
    [ ! -f "$1" ] && log_error "File not found: $1" && return 1
    return 0
}

# Load config
source "${SCRIPT_DIR}/lib/config.sh"

# HTTP client (simplified)
http_request() {
    local method="$1" url="$2" data_file="${3:-}" max_retries="${4:-3}"
    local attempt=0 http_code response
    
    while [ $attempt -lt $max_retries ]; do
        if [ -n "$data_file" ] && [ -f "$data_file" ]; then
            response=$(curl -s -w "\n%{http_code}" -X "$method" -H "Content-Type: application/json" -d @"$data_file" "$url" 2>&1) || {
                [ $((++attempt)) -lt $max_retries ] && sleep $((attempt * 2)) && continue || return 1
            }
        else
            response=$(curl -s -w "\n%{http_code}" -X "$method" -H "Accept: application/json" "$url" 2>&1) || {
                [ $((++attempt)) -lt $max_retries ] && sleep $((attempt * 2)) && continue || return 1
            }
        fi
        
        http_code=$(echo "$response" | tail -n1)
        response_body=$(echo "$response" | sed '$d')
        
        [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ] && echo "$response_body" && return 0
        [ "$http_code" -ge 400 ] && [ "$http_code" -lt 500 ] && log_error "HTTP $http_code: $response_body" && return 1
        [ $((++attempt)) -lt $max_retries ] && sleep $((attempt * 2))
    done
    
    error_exit "HTTP request failed after $max_retries attempts"
}

pretty_json() {
    echo "${1:-}" | jq '.' 2>/dev/null || echo "${1:-}"
}

# Spec builder
source "${SCRIPT_DIR}/lib/spec-builder.sh"

# Commands
cmd_build() {
    local env="$1" output="${2:-}"
    load_config "$env" "$CONFIG_DIR" || return 1
    build_spec "$env" "$output" "$CONFIG_DIR" "$TEMPLATE_DIR"
}

cmd_compile_proto() {
    local proto_file="${1:-${SCRIPT_DIR}/schemas/proto/settlement_transaction.proto}"
    local output="${2:-${SCRIPT_DIR}/schemas/compiled/settlement_transaction.desc}"
    
    command -v protoc >/dev/null 2>&1 || error_exit "protoc not found. Install with: brew install protobuf (macOS) or apt-get install protobuf-compiler (Linux)"
    
    mkdir -p "$(dirname "$output")"
    protoc --descriptor_set_out="$output" --proto_path="$(dirname "$proto_file")" "$proto_file" || error_exit "Failed to compile protobuf"
    echo "$output"
}

cmd_deploy() {
    local env="$1"
    load_config "$env" "$CONFIG_DIR" || return 1
    
    local spec_file="${SPECS_DIR}/supervisor-spec-${DATASOURCE}-${env}.json"
    [ ! -f "$spec_file" ] && build_spec "$env" "$spec_file" "$CONFIG_DIR" "$TEMPLATE_DIR"
    
    local response
    response=$(http_request "POST" "${DRUID_URL}/druid/indexer/v1/supervisor" "$spec_file") || return 1
    log_info "Supervisor deployed: $DATASOURCE"
    pretty_json "$response"
}

cmd_status() {
    local env="$1"
    load_config "$env" "$CONFIG_DIR" || return 1
    
    local response
    response=$(http_request "GET" "${DRUID_URL}/druid/indexer/v1/supervisor/${DATASOURCE}/status") || return 1
    pretty_json "$response"
}

# Usage
usage() {
    cat << EOF
Druid Ingestion Manager - Shell Solution

Usage: $0 <command> [options]

Commands:
    build           Build supervisor specification JSON
    compile-proto   Compile protobuf descriptor file
    deploy          Deploy supervisor to Druid Overlord
    status          Get supervisor status

Options:
    -e, --env   Environment (dev, staging, prod) [required]
    -o, --output Output file path (for build command)

Examples:
    $0 build -e dev
    $0 build -e dev -o /tmp/spec.json
    $0 compile-proto
    $0 deploy -e dev
    $0 status -e dev
EOF
}

# Main
main() {
    check_prerequisites
    
    local command="${1:-}"
    shift || true
    
    case "$command" in
        build)
            local env="" output=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -e|--env) env="$2"; shift 2 ;;
                    -o|--output) output="$2"; shift 2 ;;
                    *) error_exit "Unknown option: $1" ;;
                esac
            done
            [ -z "$env" ] && error_exit "Environment (-e) is required"
            cmd_build "$env" "$output" || exit 1
            ;;
        compile-proto)
            local proto_file="" output=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -f|--file) proto_file="$2"; shift 2 ;;
                    -o|--output) output="$2"; shift 2 ;;
                    *) error_exit "Unknown option: $1" ;;
                esac
            done
            cmd_compile_proto "$proto_file" "$output" || exit 1
            ;;
        deploy)
            local env=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -e|--env) env="$2"; shift 2 ;;
                    *) error_exit "Unknown option: $1" ;;
                esac
            done
            [ -z "$env" ] && error_exit "Environment (-e) is required"
            cmd_deploy "$env" || exit 1
            ;;
        status)
            local env=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -e|--env) env="$2"; shift 2 ;;
                    *) error_exit "Unknown option: $1" ;;
                esac
            done
            [ -z "$env" ] && error_exit "Environment (-e) is required"
            cmd_status "$env" || exit 1
            ;;
        help|--help|-h) usage ;;
        *) [ -z "$command" ] && usage || error_exit "Unknown command: $command. Use 'help' for usage." ;;
    esac
}

main "$@"
