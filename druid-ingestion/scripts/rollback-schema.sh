#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

[ $# -ne 2 ] && { echo "Usage: $0 <schema_version> <environment>" >&2; exit 1; }

SCHEMA_VERSION=$1
ENV=$2

validate_environment "$ENV"
load_config "$ENV"
validate_vars "$MODULE_ROOT/config/${ENV}.env" S3_BUCKET

S3_PATH="s3://${S3_BUCKET}/schemas/${SCHEMA_VERSION}/"

aws s3 ls "$S3_PATH" &>/dev/null || {
    echo "ERROR: Schema not found: $S3_PATH" >&2
    echo "Available versions:"
    aws s3 ls "s3://${S3_BUCKET}/schemas/" 2>/dev/null | grep "PRE" | awk '{print "  " $2}' || echo "  (none)"
    exit 1
}

echo "Rollback to schema: $SCHEMA_VERSION (env: $ENV)"
[ "$ENV" = "prod" ] && echo "WARNING: PRODUCTION environment"
read -p "Continue? (yes/no): " -r
[[ ! $REPLY =~ ^[Yy]es$ ]] && { echo "Cancelled"; exit 0; }

"$SCRIPT_DIR/deploy-supervisor.sh" "$ENV" "$SCHEMA_VERSION"
echo "Rollback completed: $SCHEMA_VERSION"
