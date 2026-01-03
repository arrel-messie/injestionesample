#!/usr/bin/env bash
#
# Config module - Optimized with mapping table
#

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Get JSON value using jq
_json_get() {
    local file="$1" key="$2" default="${3:-}"
    command -v jq >/dev/null 2>&1 || { echo "$default"; return; }
    jq -r "$key // \"$default\"" "$file" 2>/dev/null || echo "$default"
}

# Load configuration from defaults.json and environment .env
load_config() {
    local env="${1:-}" config_dir="${2:-}"
    
    [ -z "$env" ] && log_error "Environment is required" && return 1
    [[ ! "$env" =~ ^(dev|staging|prod|test)$ ]] && log_error "Invalid environment: $env" && return 1
    [ -z "$config_dir" ] && config_dir="$(dirname "${BASH_SOURCE[0]}")/../config"
    
    local defaults_file="${config_dir}/defaults.json"
    local env_file="${config_dir}/${env}.env"
    
    # Load defaults from JSON using mapping table
    [ -f "$defaults_file" ] && {
        local mappings=(
            "KAFKA_BOOTSTRAP_SERVERS:.kafka.bootstrapServers:localhost:9092"
            "KAFKA_SECURITY_PROTOCOL:.kafka.securityProtocol:PLAINTEXT"
            "KAFKA_SASL_MECHANISM:.kafka.saslMechanism:PLAIN"
            "KAFKA_SASL_JAAS_CONFIG:.kafka.saslJaasConfig:"
            "KAFKA_SSL_ENDPOINT_ID:.kafka.sslEndpointIdentificationAlgorithm:"
            "KAFKA_TOPIC:.kafka.topic:settlement-transactions"
            "PROTO_DESCRIPTOR_PATH:.proto.descriptorPath:file:///opt/shared/schemas/settlement_transaction.desc"
            "PROTO_MESSAGE_TYPE:.proto.messageType:com.company.PaymentTransactionEvent"
            "DATASOURCE:.druid.datasource:idm_settlement_snapshot"
            "DRUID_TIMESTAMP_COLUMN:.druid.timestampColumn:settlementTimestampMs"
            "DRUID_TIMESTAMP_FORMAT:.druid.timestampFormat:millis"
            "GRANULARITY_SEGMENT:.granularity.segment:DAY"
            "GRANULARITY_QUERY:.granularity.query:NONE"
            "GRANULARITY_ROLLUP:.granularity.rollup:false"
        )
        local var key default
        for mapping in "${mappings[@]}"; do
            IFS=':' read -r var key default <<< "$mapping"
            export "$var"="${!var:-$(_json_get "$defaults_file" "$key" "$default")}"
        done
    }
    
    # Override with environment-specific .env file
    [ -f "$env_file" ] && {
        set -a
        source "$env_file"
        set +a
    } || log_warn "Environment file not found: $env_file"
    
    # Validate DRUID_URL if set
    [ -n "${DRUID_URL:-}" ] && [[ ! "${DRUID_URL}" =~ ^https?:// ]] && {
        log_error "Invalid DRUID_URL: ${DRUID_URL}"
        return 1
    }
    
    export ENV="$env"
}
