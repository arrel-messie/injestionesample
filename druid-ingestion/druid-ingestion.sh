#!/usr/bin/env bash
#
# Druid Ingestion Manager - Optimized
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
SPECS_DIR="${SCRIPT_DIR}/druid-specs/generated"

# Colors & Logging
readonly RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
error_exit() { log_error "$1"; exit "${2:-1}"; }

# Prerequisites
check_prerequisites() {
    local missing=()
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    [ ${#missing[@]} -gt 0 ] && error_exit "Missing: ${missing[*]}. Install: brew install jq curl"
}

# Parse options (generic, returns via global variables)
parse_opts() {
    PARSED_ENV="" PARSED_OUTPUT="" PARSED_FILE=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -e|--env) PARSED_ENV="$2"; shift 2 ;;
            -o|--output) PARSED_OUTPUT="$2"; shift 2 ;;
            -f|--file) PARSED_FILE="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
}

# HTTP client (simplified)
http_request() {
    local method="$1" url="$2" data_file="${3:-}" attempt=0 max_retries="${4:-3}"
    local curl_opts=(-s -w "\n%{http_code}" -X "$method")
    [ -n "$data_file" ] && [ -f "$data_file" ] && curl_opts+=(-H "Content-Type: application/json" -d @"$data_file") || curl_opts+=(-H "Accept: application/json")
    
    while [ $attempt -lt $max_retries ]; do
        local response=$(curl "${curl_opts[@]}" "$url" 2>&1) || { [ $((++attempt)) -lt $max_retries ] && sleep $((attempt * 2)) && continue || return 1; }
        local http_code=$(echo "$response" | tail -n1)
        local response_body=$(echo "$response" | sed '$d')
        [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ] && echo "$response_body" && return 0
        [ "$http_code" -ge 400 ] && [ "$http_code" -lt 500 ] && log_error "HTTP $http_code: $response_body" && return 1
        [ $((++attempt)) -lt $max_retries ] && sleep $((attempt * 2))
    done
    error_exit "HTTP request failed after $max_retries attempts"
}

pretty_json() { echo "${1:-}" | jq '.' 2>/dev/null || echo "${1:-}"; }

# Load modules
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/spec-builder.sh"

# Wrapper for commands requiring environment
with_env() {
    local cmd="$1" env="${2:-}"
    [ -z "$env" ] && error_exit "Environment (-e) is required"
    load_config "$env" "$CONFIG_DIR" || return 1
    shift 2
    "$cmd" "$env" "$@"
}

# Commands
cmd_build() {
    parse_opts "$@"
    with_env _build_impl "$PARSED_ENV" "$PARSED_OUTPUT" || return 1
}

_build_impl() {
    local env="$1" output="${2:-}"
    build_spec "$env" "$output" "$CONFIG_DIR" "$TEMPLATE_DIR"
}

cmd_compile_proto() {
    parse_opts "$@"
    local proto_file="${PARSED_FILE:-${SCRIPT_DIR}/schemas/proto/settlement_transaction.proto}"
    local output="${PARSED_OUTPUT:-${SCRIPT_DIR}/schemas/compiled/settlement_transaction.desc}"
    command -v protoc >/dev/null 2>&1 || error_exit "protoc not found. Install: brew install protobuf"
    mkdir -p "$(dirname "$output")"
    protoc --descriptor_set_out="$output" --proto_path="$(dirname "$proto_file")" "$proto_file" || error_exit "Failed to compile"
    echo "$output"
}

cmd_deploy() {
    parse_opts "$@"
    with_env _deploy_impl "$PARSED_ENV" || return 1
}

_deploy_impl() {
    local env="$1"
    local spec_file="${SPECS_DIR}/supervisor-spec-${DATASOURCE}-${env}.json"
    [ ! -f "$spec_file" ] && build_spec "$env" "$spec_file" "$CONFIG_DIR" "$TEMPLATE_DIR"
    local response
    response=$(http_request "POST" "${DRUID_URL}/druid/indexer/v1/supervisor" "$spec_file") || return 1
    log_info "Deployed: $DATASOURCE"
    pretty_json "$response"
}

cmd_status() {
    parse_opts "$@"
    with_env _status_impl "$PARSED_ENV" || return 1
}

_status_impl() {
    local env="$1"
    local response
    response=$(http_request "GET" "${DRUID_URL}/druid/indexer/v1/supervisor/${DATASOURCE}/status") || return 1
    pretty_json "$response"
}

# Usage
usage() {
    cat << EOF
Druid Ingestion Manager

Usage: $0 <command> [options]

Commands:
    build           Build supervisor spec JSON
    compile-proto   Compile protobuf descriptor
    deploy          Deploy supervisor to Druid
    status          Get supervisor status

Options:
    -e, --env       Environment (dev, staging, prod) [required]
    -o, --output    Output file path
    -f, --file      Input file path

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
    local cmd="${1:-help}"
    shift || true
    
    case "$cmd" in
        build) cmd_build "$@" || exit 1 ;;
        compile-proto) cmd_compile_proto "$@" || exit 1 ;;
        deploy) cmd_deploy "$@" || exit 1 ;;
        status) cmd_status "$@" || exit 1 ;;
        help|--help|-h) usage ;;
        *) [ "$cmd" == "help" ] && usage || error_exit "Unknown command: $cmd. Use 'help' for usage." ;;
    esac
}

main "$@"
