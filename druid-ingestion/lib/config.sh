#!/usr/bin/env bash
#
# Config module - Configuration loading and management
# Loads defaults.yml, environment-specific .env, and schema.yml
#

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validator.sh"

# Get YAML value using yq or Python fallback
_get_yaml_value() {
    local file="$1"
    local key="$2"
    local default="${3:-}"
    local value
    
    if command -v yq >/dev/null 2>&1; then
        value=$(yq eval "$key" "$file" 2>/dev/null || echo "")
    elif command -v python3 >/dev/null 2>&1; then
        value=$(python3 -c "
import yaml
import sys
try:
    with open('$file', 'r') as f:
        data = yaml.safe_load(f)
        keys = '$key'.lstrip('.').split('.')
        result = data
        for k in keys:
            result = result.get(k, {}) if isinstance(result, dict) else None
            if result is None:
                break
        print(result if isinstance(result, (str, int, bool)) and result != {} else '')
except Exception as e:
    pass
" 2>/dev/null || echo "")
    else
        value=""
    fi
    
    if [ -n "${value}" ] && [ "$value" != "null" ] && [ "$value" != "{}" ]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# Load configuration from defaults.yml and environment .env
load_config() {
    local env="${1:-}"
    local config_dir="${2:-}"
    
    if ! validate_environment "$env"; then
        return 1
    fi
    
    local defaults_file="${config_dir}/defaults.yml"
    if ! validate_file_exists "$defaults_file" "Defaults configuration"; then
        return 1
    fi
    
    # Load environment-specific .env file
    local env_file="${config_dir}/${env}.env"
    if [ -f "$env_file" ]; then
        log_debug "Loading environment file: $env_file"
        set -a
        source "$env_file" 2>/dev/null || true
        set +a
    else
        log_warn "Environment file not found: $env_file. Using defaults only."
    fi
    
    # Export config values with defaults from defaults.yml
    export KAFKA_BOOTSTRAP_SERVERS="${KAFKA_BOOTSTRAP_SERVERS:-$(_get_yaml_value "$defaults_file" ".kafka.bootstrapServers" "localhost:9092")}"
    export KAFKA_TOPIC="${KAFKA_TOPIC:-$(_get_yaml_value "$defaults_file" ".kafka.topic" "topic")}"
    export KAFKA_SECURITY_PROTOCOL="${KAFKA_SECURITY_PROTOCOL:-$(_get_yaml_value "$defaults_file" ".kafka.securityProtocol" "PLAINTEXT")}"
    export KAFKA_SASL_MECHANISM="${KAFKA_SASL_MECHANISM:-$(_get_yaml_value "$defaults_file" ".kafka.saslMechanism" "PLAIN")}"
    export KAFKA_SASL_JAAS_CONFIG="${KAFKA_SASL_JAAS_CONFIG:-$(_get_yaml_value "$defaults_file" ".kafka.saslJaasConfig" "")}"
    
    export DRUID_URL="${DRUID_URL:-$(_get_yaml_value "$defaults_file" ".druid.url" "http://localhost:8888")}"
    export DATASOURCE="${DATASOURCE:-$(_get_yaml_value "$defaults_file" ".druid.datasource" "datasource")}"
    export DRUID_TIMESTAMP_COLUMN="${DRUID_TIMESTAMP_COLUMN:-$(_get_yaml_value "$defaults_file" ".druid.timestampColumn" "settlementTimestampMs")}"
    export DRUID_TIMESTAMP_FORMAT="${DRUID_TIMESTAMP_FORMAT:-$(_get_yaml_value "$defaults_file" ".druid.timestampFormat" "millis")}"
    
    export PROTO_DESCRIPTOR_PATH="${PROTO_DESCRIPTOR_PATH:-$(_get_yaml_value "$defaults_file" ".protobuf.descriptorPath" "file:///opt/shared/schemas/settlement_transaction.desc")}"
    export PROTO_MESSAGE_TYPE="${PROTO_MESSAGE_TYPE:-$(_get_yaml_value "$defaults_file" ".protobuf.messageType" "com.company.PaymentTransactionEvent")}"
    
    # Task config
    export TASK_USE_EARLIEST_OFFSET="${TASK_USE_EARLIEST_OFFSET:-$(_get_yaml_value "$defaults_file" ".task.useEarliestOffset" "false")}"
    export TASK_COUNT="${TASK_COUNT:-$(_get_yaml_value "$defaults_file" ".task.taskCount" "10")}"
    export TASK_REPLICAS="${TASK_REPLICAS:-$(_get_yaml_value "$defaults_file" ".task.replicas" "2")}"
    export TASK_DURATION="${TASK_DURATION:-$(_get_yaml_value "$defaults_file" ".task.taskDuration" "PT1H")}"
    
    # Tuning config
    export TUNING_MAX_ROWS_IN_MEMORY="${TUNING_MAX_ROWS_IN_MEMORY:-$(_get_yaml_value "$defaults_file" ".tuning.maxRowsInMemory" "500000")}"
    export TUNING_MAX_ROWS_PER_SEGMENT="${TUNING_MAX_ROWS_PER_SEGMENT:-$(_get_yaml_value "$defaults_file" ".tuning.maxRowsPerSegment" "5000000")}"
    export TUNING_REPORT_PARSE_EXCEPTIONS="${TUNING_REPORT_PARSE_EXCEPTIONS:-$(_get_yaml_value "$defaults_file" ".tuning.reportParseExceptions" "true")}"
    
    # Granularity config
    export GRANULARITY_SEGMENT="${GRANULARITY_SEGMENT:-$(_get_yaml_value "$defaults_file" ".granularity.segmentGranularity" "DAY")}"
    export GRANULARITY_QUERY="${GRANULARITY_QUERY:-$(_get_yaml_value "$defaults_file" ".granularity.queryGranularity" "NONE")}"
    export GRANULARITY_ROLLUP="${GRANULARITY_ROLLUP:-$(_get_yaml_value "$defaults_file" ".granularity.rollup" "false")}"
    
    log_debug "Configuration loaded for environment: $env"
    return 0
}

# Load schema from schema.yml
load_schema() {
    local schema_file="${1:-}"
    
    if ! validate_file_exists "$schema_file" "Schema"; then
        return 1
    fi
    
    # Schema is loaded by spec-builder using jq/yq
    export SCHEMA_FILE="$schema_file"
    log_debug "Schema file loaded: $schema_file"
    return 0
}

