#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
SPECS_DIR="${SCRIPT_DIR}/druid-specs/generated"

source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/spec-builder.sh"

check_prerequisites() {
    local missing=()
    for cmd in jq curl; do
        command -v "$cmd" >/dev/null || missing+=("$cmd")
    done
    [ ${#missing[@]} -gt 0 ] && error_exit "Missing: ${missing[*]}. Install: brew install ${missing[*]}"
}

parse_opts() {
    local _env="" _output="" _file=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -e|--env) _env="$2"; shift 2 ;;
            -o|--output) _output="$2"; shift 2 ;;
            -f|--file) _file="$2"; shift 2 ;;
            -v|--verbose) export VERBOSE=1; shift ;;
            -vv) export VERBOSE=2; shift ;;
            *) shift ;;
        esac
    done
    ENV="$_env" OUTPUT="$_output" FILE="$_file"
}

http_request() {
    local method="$1" url="$2" data_file="${3:-}"
    local opts=(-s -w "\n%{http_code}" -X "$method")
    [[ -n "$data_file" && -f "$data_file" ]] \
        && opts+=(-H "Content-Type: application/json" -d @"$data_file") \
        || opts+=(-H "Accept: application/json")
    
    local response=$(curl "${opts[@]}" "$url" 2>&1) || return 1
    local code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    [[ "$code" =~ ^2[0-9]{2}$ ]] && echo "$body" && return 0
    [[ "$code" =~ ^[45][0-9]{2}$ ]] && log_error "HTTP $code: $body" && return 1
    log_error "Unexpected HTTP code: $code" && return 1
}

with_env() {
    local env="${1:?Environment (-e) required}"
    load_config "$env" "$CONFIG_DIR"
}

cmd_build() {
    parse_opts "$@"
    [[ -z "$ENV" ]] && error_exit "Environment (-e) is required"
    [[ ! "$ENV" =~ ^(dev|staging|prod|test)$ ]] && error_exit "Invalid environment: $ENV"
    with_env "$ENV"
    build_spec "$ENV" "$OUTPUT" "$CONFIG_DIR" "$TEMPLATE_DIR"
}

cmd_compile_proto() {
    parse_opts "$@"
    FILE="${FILE:-${SCRIPT_DIR}/schemas/proto/settlement_transaction.proto}"
    OUTPUT="${OUTPUT:-${SCRIPT_DIR}/schemas/compiled/settlement_transaction.desc}"

    [[ ! -f "$FILE" ]] && error_exit "Proto file not found: $FILE"
    command -v protoc >/dev/null || error_exit "protoc not found. Install: brew install protobuf"
    
    mkdir -p "$(dirname "$OUTPUT")" || error_exit "Failed to create output directory"
    protoc --descriptor_set_out="$OUTPUT" --proto_path="$(dirname "$FILE")" "$FILE" || error_exit "Failed to compile proto"
    [[ -f "$OUTPUT" ]] || error_exit "Output file not created: $OUTPUT"
    echo "$OUTPUT"
}

cmd_deploy() {
    parse_opts "$@"
    [[ -z "$ENV" ]] && error_exit "Environment (-e) is required"
    [[ ! "$ENV" =~ ^(dev|staging|prod|test)$ ]] && error_exit "Invalid environment: $ENV"
    with_env "$ENV"
    
    [[ -z "${DATASOURCE:-}" ]] && error_exit "DATASOURCE not set in config"
    [[ -z "${DRUID_URL:-}" ]] && error_exit "DRUID_URL not set in config"

    local spec="${SPECS_DIR}/supervisor-spec-${DATASOURCE}-${ENV}.json"
    [[ ! -f "$spec" ]] && build_spec "$ENV" "$spec" "$CONFIG_DIR" "$TEMPLATE_DIR"
    [[ ! -f "$spec" ]] && error_exit "Spec file not found: $spec"

    http_request "POST" "${DRUID_URL}/druid/indexer/v1/supervisor" "$spec" | jq '.' || cat
    log_info "Deployed: $DATASOURCE"
}

cmd_status() {
    parse_opts "$@"
    [[ -z "$ENV" ]] && error_exit "Environment (-e) is required"
    [[ ! "$ENV" =~ ^(dev|staging|prod|test)$ ]] && error_exit "Invalid environment: $ENV"
    with_env "$ENV"
    
    [[ -z "${DATASOURCE:-}" ]] && error_exit "DATASOURCE not set in config"
    [[ -z "${DRUID_URL:-}" ]] && error_exit "DRUID_URL not set in config"
    
    http_request "GET" "${DRUID_URL}/druid/indexer/v1/supervisor/${DATASOURCE}/status" | jq '.' || cat
}

usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
  build           Build supervisor spec JSON
  compile-proto   Compile protobuf descriptor
  deploy          Deploy supervisor to Druid
  status          Get supervisor status

Options:
  -e, --env       Environment (dev/staging/prod/test) [required]
  -o, --output    Output file path
  -f, --file      Input file path
  -v, --verbose   Verbose output
  -vv             Debug output

Examples:
  $0 build -e dev
  $0 deploy -e dev
  $0 status -e dev
EOF
}
main() {
    check_prerequisites
    case "${1:-help}" in
        build|compile-proto|deploy|status) "cmd_$1" "${@:2}" ;;
        help|--help|-h) usage ;;
        *) error_exit "Unknown: $1. Use '$0 help'" ;;
    esac
}
main "$@"