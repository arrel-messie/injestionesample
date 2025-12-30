#!/bin/bash
# rollback-schema.sh - Rollback Druid supervisor to a previous schema version

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

[ $# -ne 2 ] && {
    echo "Usage: $0 <schema_version> <environment>" >&2
    exit 1
}

SCHEMA_VERSION=$1
ENVIRONMENT=$2

validate_environment "$ENVIRONMENT"
load_config "$ENVIRONMENT"
validate_vars "$MODULE_ROOT/config/${ENVIRONMENT}.env" S3_BUCKET DRUID_OVERLORD_URL

S3_PATH="s3://${S3_BUCKET}/schemas/${SCHEMA_VERSION}/"

echo "Rollback to schema version: $SCHEMA_VERSION"
echo "Environment: $ENVIRONMENT"
echo ""

echo "Checking schema existence on S3: $S3_PATH"
aws s3 ls "$S3_PATH" &> /dev/null || {
    echo "ERROR: Schema not found: $S3_PATH" >&2
    echo ""
    echo "Available versions:"
    aws s3 ls "s3://${S3_BUCKET}/schemas/" 2>/dev/null | grep "PRE" | awk '{print "  " $2}' || echo "  (none found)"
    exit 1
}

echo "Schema found on S3"
echo "Files in this version:"
aws s3 ls "$S3_PATH" 2>/dev/null | head -10

echo ""
echo "WARNING: This operation will redeploy the supervisor"
[ "$ENVIRONMENT" = "prod" ] && echo "WARNING: You are about to modify PRODUCTION"

read -p "Continue with rollback? (yes/no): " -r
echo
[[ ! $REPLY =~ ^[Yy]es$ ]] && { echo "Rollback cancelled"; exit 0; }

echo "Deploying schema version: $SCHEMA_VERSION"
"$SCRIPT_DIR/deploy-supervisor.sh" "$ENVIRONMENT" "$SCHEMA_VERSION" || {
    echo "ERROR: Rollback failed" >&2
    exit 1
}

echo ""
echo "Rollback completed successfully"
echo "Supervisor is now using schema version: $SCHEMA_VERSION"
