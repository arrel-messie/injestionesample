#!/usr/bin/env bash
#
# Logger module - Simple logging functions
#

[ -z "${RED:-}" ] && readonly RED='\033[0;31m'
[ -z "${GREEN:-}" ] && readonly GREEN='\033[0;32m'
[ -z "${YELLOW:-}" ] && readonly YELLOW='\033[1;33m'
[ -z "${NC:-}" ] && readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
error_exit() { log_error "$1"; exit "${2:-1}"; }
