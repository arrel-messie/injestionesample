#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
SPECS_DIR="${SCRIPT_DIR}/druid-specs/generated"

source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/spec-builder.sh"

# Vérifie les dépendances
check_prerequisites() {
    local missing=()
    for cmd in jq curl; do
        command -v "$cmd" >/dev/null || missing+=("$cmd")
    done
    [ ${#missing[@]} -gt 0 ] && error_exit "Missing: ${missing[*]}. Install: brew install ${missing[*]}"
}

# Parse les options communes (-e, -o, -f)
parse_opts() {
    ENV="" OUTPUT="" FILE=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -e|--env) ENV="$2"; shift 2 ;;
            -o|--output) OUTPUT="$2"; shift 2 ;;
            -f|--file) FILE="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
}

http_request() {
    local method="$1" url="$2" data_file="${3:-}"
    if [[ -n "$data_file" && -f "$data_file" ]]; then
        curl -s -X "$method" -H "Content-Type: application/json" -d @"$data_file" "$url"
    else
        curl -s -X "$method" -H "Accept: application/json" "$url"
    fi
}

# Charge l'env et valide
with_env() {
    local env="${1:?Environment (-e) required}"
    load_config "$env" "$CONFIG_DIR"
}

# === Commandes ===

cmd_build() {
    parse_opts "$@"
    with_env "$ENV"
    build_spec "$ENV" "$OUTPUT" "$CONFIG_DIR" "$TEMPLATE_DIR"
}

cmd_compile_proto() {
    parse_opts "$@"
    FILE="${FILE:-${SCRIPT_DIR}/schemas/proto/settlement_transaction.proto}"
    OUTPUT="${OUTPUT:-${SCRIPT_DIR}/schemas/compiled/settlement_transaction.desc}"

    command -v protoc >/dev/null || error_exit "protoc not found. Install: brew install protobuf"
    mkdir -p "$(dirname "$OUTPUT")"
    protoc --descriptor_set_out="$OUTPUT" --proto_path="$(dirname "$FILE")" "$FILE"
    echo "$OUTPUT"
}

cmd_deploy() {
    parse_opts "$@"
    with_env "$ENV"

    local spec="${SPECS_DIR}/supervisor-spec-${DATASOURCE}-${ENV}.json"
    [[ ! -f "$spec" ]] && build_spec "$ENV" "$spec" "$CONFIG_DIR" "$TEMPLATE_DIR"

    http_request "POST" "${DRUID_URL}/druid/indexer/v1/supervisor" "$spec" | jq '.' || cat
    log_info "✓ Deployed: $DATASOURCE"
}

cmd_status() {
    parse_opts "$@"
    with_env "$ENV"
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
  -e, --env       Environment (dev/staging/prod) [required]
  -o, --output    Output file path
  -f, --file      Input file path

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