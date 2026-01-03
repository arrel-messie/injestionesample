#!/usr/bin/env bash
#
# Config module - Optimized version
#

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/yaml-helper.sh"

# Load configuration from defaults.yml and environment .env
load_config() {
    local env="${1:-}"
    local config_dir="${2:-}"
    
    [ -z "$env" ] && log_error "Environment is required" && return 1
    [ -z "$config_dir" ] && config_dir="$(dirname "${BASH_SOURCE[0]}")/../config"
    
    local defaults_file="${config_dir}/defaults.yml"
    local env_file="${config_dir}/${env}.env"
    
    # Load defaults from YAML (using helper function)
    [ -f "$defaults_file" ] && {
        local defaults=(
            ".kafka.bootstrapServers:KAFKA_BOOTSTRAP_SERVERS:localhost:9092"
            ".kafka.securityProtocol:KAFKA_SECURITY_PROTOCOL:PLAINTEXT"
            ".kafka.saslMechanism:KAFKA_SASL_MECHANISM:PLAIN"
            ".kafka.saslJaasConfig:KAFKA_SASL_JAAS_CONFIG:"
            ".kafka.sslEndpointIdentificationAlgorithm:KAFKA_SSL_ENDPOINT_ID:"
            ".kafka.topic:KAFKA_TOPIC:settlement-transactions"
            ".proto.descriptorPath:PROTO_DESCRIPTOR_PATH:file:///opt/shared/schemas/settlement_transaction.desc"
            ".proto.messageType:PROTO_MESSAGE_TYPE:com.company.PaymentTransactionEvent"
            ".druid.datasource:DATASOURCE:idm_settlement_snapshot"
            ".druid.timestampColumn:DRUID_TIMESTAMP_COLUMN:settlementTimestampMs"
            ".druid.timestampFormat:DRUID_TIMESTAMP_FORMAT:millis"
            ".granularity.segment:GRANULARITY_SEGMENT:DAY"
            ".granularity.query:GRANULARITY_QUERY:NONE"
            ".granularity.rollup:GRANULARITY_ROLLUP:false"
        )
        for entry in "${defaults[@]}"; do
            IFS=':' read -r key var default <<< "$entry"
            yaml_export "$defaults_file" "$key" "$var" "$default"
        done
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

