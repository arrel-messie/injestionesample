#!/usr/bin/env bash

[ -z "${RED:-}" ] && readonly RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' NC='\033[0m'
readonly VERBOSE="${VERBOSE:-0}"

log_info() { [[ "$VERBOSE" -ge 1 ]] && echo -e "${GREEN}[INFO]${NC} $*" >&2 || true; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_debug() { [[ "$VERBOSE" -ge 2 ]] && echo -e "[DEBUG] $*" >&2 || true; }
error_exit() { log_error "$1"; exit "${2:-1}"; }
