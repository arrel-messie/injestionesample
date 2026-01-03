#!/usr/bin/env bash
#
# Config module - Simplified using JSON directly
#

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Get JSON value using jq
_json_get() {
    local file="$1"
    local key="$2"
    local default="${3:-}"
    command -v jq >/dev/null 2>&1 || { echo "$default"; return; }
    jq -r "$key // \"$default\"" "$file" 2>/dev/null || echo "$default"
}

# Load configuration from defaults.json and environment .env
load_config() {
    local env="${1:-}"
    local config_dir="${2:-}"
    
    [ -z "$env" ] && log_error "Environment is required" && return 1
    [ -z "$config_dir" ] && config_dir="$(dirname "${BASH_SOURCE[0]}")/../config"
    
    local defaults_file="${config_dir}/defaults.json"
    local env_file="${config_dir}/${env}.env"
    
    # Load defaults from JSON
    [ -f "$defaults_file" ] && {
        export KAFKA_BOOTSTRAP_SERVERS="${KAFKA_BOOTSTRAP_SERVERS:-$(_json_get "$defaults_file" ".kafka.bootstrapServers" "localhost:9092")}"
        export KAFKA_SECURITY_PROTOCOL="${KAFKA_SECURITY_PROTOCOL:-$(_json_get "$defaults_file" ".kafka.securityProtocol" "PLAINTEXT")}"
        export KAFKA_SASL_MECHANISM="${KAFKA_SASL_MECHANISM:-$(_json_get "$defaults_file" ".kafka.saslMechanism" "PLAIN")}"
        export KAFKA_SASL_JAAS_CONFIG="${KAFKA_SASL_JAAS_CONFIG:-$(_json_get "$defaults_file" ".kafka.saslJaasConfig" "")}"
        export KAFKA_SSL_ENDPOINT_ID="${KAFKA_SSL_ENDPOINT_ID:-$(_json_get "$defaults_file" ".kafka.sslEndpointIdentificationAlgorithm" "")}"
        export KAFKA_TOPIC="${KAFKA_TOPIC:-$(_json_get "$defaults_file" ".kafka.topic" "settlement-transactions")}"
        export PROTO_DESCRIPTOR_PATH="${PROTO_DESCRIPTOR_PATH:-$(_json_get "$defaults_file" ".proto.descriptorPath" "file:///opt/shared/schemas/settlement_transaction.desc")}"
        export PROTO_MESSAGE_TYPE="${PROTO_MESSAGE_TYPE:-$(_json_get "$defaults_file" ".proto.messageType" "com.company.PaymentTransactionEvent")}"
        export DATASOURCE="${DATASOURCE:-$(_json_get "$defaults_file" ".druid.datasource" "idm_settlement_snapshot")}"
        export DRUID_TIMESTAMP_COLUMN="${DRUID_TIMESTAMP_COLUMN:-$(_json_get "$defaults_file" ".druid.timestampColumn" "settlementTimestampMs")}"
        export DRUID_TIMESTAMP_FORMAT="${DRUID_TIMESTAMP_FORMAT:-$(_json_get "$defaults_file" ".druid.timestampFormat" "millis")}"
        export GRANULARITY_SEGMENT="${GRANULARITY_SEGMENT:-$(_json_get "$defaults_file" ".granularity.segment" "DAY")}"
        export GRANULARITY_QUERY="${GRANULARITY_QUERY:-$(_json_get "$defaults_file" ".granularity.query" "NONE")}"
        export GRANULARITY_ROLLUP="${GRANULARITY_ROLLUP:-$(_json_get "$defaults_file" ".granularity.rollup" "false")}"
    }
    
    # Override with environment-specific .env file
    [ -f "$env_file" ] && {
        log_info "Loading environment config: $env_file"
        set -a
        source "$env_file"
        set +a
    } || log_warn "Environment file not found: $env_file"
    
    export ENV="$env"
    log_info "Configuration loaded for environment: $env"
}

