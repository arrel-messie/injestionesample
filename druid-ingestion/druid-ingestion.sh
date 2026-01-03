#!/usr/bin/env bash
#
# Druid Ingestion Manager - Shell Solution
# Professional, maintainable shell script for managing Druid supervisor deployments
#
# Usage:
#   ./druid-ingestion.sh build -e dev
#   ./druid-ingestion.sh deploy -e dev
#   ./druid-ingestion.sh status -e dev
#

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/prerequisites.sh"

# Error handling
error_exit() {
    log_error "$1"
    exit "${2:-1}"
}

# Show usage
usage() {
    cat << EOF
Druid Ingestion Manager - Shell Solution

Usage:
    $0 <command> [options]

Commands:
    build       Build supervisor specification JSON
    deploy      Deploy supervisor to Druid Overlord
    status      Get supervisor status

Options:
    -e, --env   Environment (dev, staging, prod) [required]
    -o, --output Output file path (for build command)

Examples:
    $0 build -e dev
    $0 build -e dev -o /tmp/spec.json
    $0 deploy -e dev
    $0 status -e dev

EOF
}

# Main
main() {
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    local command="${1:-}"
    shift || true
    
    case "$command" in
        build)
            local env=""
            local output=""
            
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -e|--env)
                        env="$2"
                        shift 2
                        ;;
                    -o|--output)
                        output="$2"
                        shift 2
                        ;;
                    *)
                        error_exit "Unknown option: $1"
                        ;;
                esac
            done
            
            source "${SCRIPT_DIR}/commands/build.sh"
            execute_build "$env" "$output" || exit 1
            ;;
            
        deploy)
            local env=""
            
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -e|--env)
                        env="$2"
                        shift 2
                        ;;
                    *)
                        error_exit "Unknown option: $1"
                        ;;
                esac
            done
            
            source "${SCRIPT_DIR}/commands/deploy.sh"
            execute_deploy "$env" || exit 1
            ;;
            
        status)
            local env=""
            
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -e|--env)
                        env="$2"
                        shift 2
                        ;;
                    *)
                        error_exit "Unknown option: $1"
                        ;;
                esac
            done
            
            source "${SCRIPT_DIR}/commands/status.sh"
            execute_status "$env" || exit 1
            ;;
            
        help|--help|-h)
            usage
            ;;
            
        *)
            if [ -z "$command" ]; then
                usage
            else
                error_exit "Unknown command: $command. Use 'help' for usage."
            fi
            ;;
    esac
}

# Run main function
main "$@"
