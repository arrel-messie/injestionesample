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
CONFIG_DIR="${SCRIPT_DIR}/config"
SCHEMAS_DIR="${SCRIPT_DIR}/schemas"
SPECS_DIR="${SCRIPT_DIR}/druid-specs/generated"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Error handling
error_exit() {
    log_error "$1"
    exit "${2:-1}"
}

# Check prerequisites
check_prerequisites() {
    local missing=()
    
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v yq >/dev/null 2>&1 || missing+=("yq")
    
    if [ ${#missing[@]} -gt 0 ]; then
        error_exit "Missing required tools: ${missing[*]}. Install with: brew install jq yq (macOS) or apt-get install jq yq (Linux)"
    fi
}

# Load configuration
load_config() {
    local env="${1:-}"
    
    if [ -z "$env" ]; then
        error_exit "Environment (-e) is required. Use: dev, staging, or prod"
    fi
    
    if [[ ! "$env" =~ ^(dev|staging|prod|test)$ ]]; then
        error_exit "Invalid environment: $env. Must be one of: dev, staging, prod, test"
    fi
    
    # Load defaults.yml
    if [ ! -f "${CONFIG_DIR}/defaults.yml" ]; then
        error_exit "Configuration file not found: ${CONFIG_DIR}/defaults.yml"
    fi
    
    # Load environment-specific .env file
    local env_file="${CONFIG_DIR}/${env}.env"
    if [ -f "$env_file" ]; then
        # Source .env file (simple key=value format)
        set -a
        source "$env_file" 2>/dev/null || true
        set +a
    else
        log_warn "Environment file not found: $env_file. Using defaults only."
    fi
    
    # Export config values with defaults
    export KAFKA_BOOTSTRAP_SERVERS="${KAFKA_BOOTSTRAP_SERVERS:-$(get_config '.kafka.bootstrapServers' 'localhost:9092')}"
    export KAFKA_TOPIC="${KAFKA_TOPIC:-$(get_config '.kafka.topic' 'topic')}"
    export DRUID_URL="${DRUID_URL:-$(get_config '.druid.url' 'http://localhost:8888')}"
    export DATASOURCE="${DATASOURCE:-$(get_config '.druid.datasource' 'datasource')}"
    export PROTO_DESCRIPTOR_PATH="${PROTO_DESCRIPTOR_PATH:-$(get_config '.protobuf.descriptorPath' 'file:///opt/shared/schemas/settlement_transaction.desc')}"
}

# Get config value from YAML with fallback
get_config() {
    local key="$1"
    local default="${2:-}"
    local value
    
    # Try yq first, fallback to Python if available
    if command -v yq >/dev/null 2>&1; then
        value=$(yq eval "$key" "${CONFIG_DIR}/defaults.yml" 2>/dev/null || echo "")
    elif command -v python3 >/dev/null 2>&1; then
        value=$(python3 -c "
import yaml
import sys
try:
    with open('${CONFIG_DIR}/defaults.yml', 'r') as f:
        data = yaml.safe_load(f)
        keys = '$key'.split('.')
        result = data
        for k in keys:
            result = result.get(k, {})
        print(result if isinstance(result, (str, int, bool)) else '')
except:
    pass
" 2>/dev/null || echo "")
    else
        value=""
    fi
    
    if [ -n "${value}" ] && [ "$value" != "null" ]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# Build supervisor spec
build_spec() {
    local env="$1"
    local output="${2:-}"
    
    log_info "Building supervisor spec for environment: $env"
    
    load_config "$env"
    
    # Load schema.yml
    if [ ! -f "${CONFIG_DIR}/schema.yml" ]; then
        error_exit "Schema file not found: ${CONFIG_DIR}/schema.yml"
    fi
    
    # Determine output file
    if [ -z "$output" ]; then
        mkdir -p "$SPECS_DIR"
        output="${SPECS_DIR}/supervisor-spec-${DATASOURCE}-${env}.json"
    else
        mkdir -p "$(dirname "$output")"
    fi
    
    log_info "Generating spec: $output"
    
    # Build spec using jq (professional JSON manipulation)
    jq -n \
        --arg env "$env" \
        --arg datasource "$DATASOURCE" \
        --arg kafka_topic "$KAFKA_TOPIC" \
        --arg kafka_bootstrap "$KAFKA_BOOTSTRAP_SERVERS" \
        --arg druid_url "$DRUID_URL" \
        --arg proto_descriptor "$PROTO_DESCRIPTOR_PATH" \
        --argfile schema "${CONFIG_DIR}/schema.yml" \
        --argfile defaults "${CONFIG_DIR}/defaults.yml" \
        '
        # Helper function to build dimensions spec
        def build_dimensions:
            {
                dimensions: ($schema.dimensions // []),
                dimensionExclusions: ["settlement_ts", "settlement_entry_ts", "acceptance_ts", "payee_access_manager_id"],
                includeAllDimensions: false,
                useSchemaDiscovery: false
            };
        
        # Helper function to build metrics spec
        def build_metrics:
            $schema.metrics // [];
        
        # Helper function to build transforms spec
        def build_transforms:
            {
                transforms: ($schema.transforms // [] | map({
                    type: "expression",
                    name: .name,
                    expression: .expression
                })),
                filter: null
            };
        
        # Build complete spec
        {
            type: "kafka",
            spec: {
                ioConfig: {
                    type: "kafka",
                    consumerProperties: {
                        "bootstrap.servers": $kafka_bootstrap,
                        "security.protocol": ($defaults.kafka.securityProtocol // "PLAINTEXT"),
                        "sasl.mechanism": ($defaults.kafka.saslMechanism // "PLAIN"),
                        "sasl.jaas.config": ($defaults.kafka.saslJaasConfig // ""),
                        "ssl.endpoint.identification.algorithm": ($defaults.kafka.sslEndpointId // ""),
                        "group.id": "druid-\($datasource)-\($env)",
                        "fetch.min.bytes": ($defaults.kafka.fetchMinBytes // 1048576),
                        "fetch.max.wait.ms": ($defaults.kafka.fetchMaxWaitMs // 500),
                        "max.poll.records": ($defaults.kafka.maxPollRecords // 500),
                        "session.timeout.ms": ($defaults.kafka.sessionTimeoutMs // 30000),
                        "heartbeat.interval.ms": ($defaults.kafka.heartbeatIntervalMs // 3000),
                        "max.poll.interval.ms": ($defaults.kafka.maxPollIntervalMs // 300000),
                        "enable.auto.commit": false,
                        "auto.offset.reset": ($defaults.kafka.autoOffsetReset // "latest")
                    },
                    topic: $kafka_topic,
                    inputFormat: {
                        type: "protobuf",
                        protoBytesDecoder: {
                            type: "file",
                            descriptor: $proto_descriptor,
                            protoMessageType: ($defaults.protobuf.messageType // "com.company.PaymentTransactionEvent")
                        }
                    },
                    useEarliestOffset: ($defaults.task.useEarliestOffset // false),
                    useTransaction: ($defaults.task.useTransaction // true),
                    taskCount: ($defaults.task.taskCount // 10),
                    replicas: ($defaults.task.replicas // 2),
                    taskDuration: ($defaults.task.taskDuration // "PT1H"),
                    startDelay: ($defaults.task.startDelay // "PT5S"),
                    period: ($defaults.task.period // "PT30S"),
                    completionTimeout: ($defaults.task.completionTimeout // "PT1H"),
                    lateMessageRejectionPeriod: ($defaults.task.lateMessageRejectionPeriod // "PT1H"),
                    pollTimeout: ($defaults.task.pollTimeout // 100),
                    minimumMessageTime: ($defaults.task.minimumMessageTime // "1970-01-01T00:00:00.000Z")
                },
                tuningConfig: {
                    type: "kafka",
                    maxRowsInMemory: ($defaults.tuning.maxRowsInMemory // 500000),
                    maxBytesInMemory: ($defaults.tuning.maxBytesInMemory // 536870912),
                    maxRowsPerSegment: ($defaults.tuning.maxRowsPerSegment // 5000000),
                    maxTotalRows: null,
                    intermediatePersistPeriod: "PT10M",
                    maxPendingPersists: ($defaults.tuning.maxPendingPersists // 2),
                    reportParseExceptions: ($defaults.tuning.reportParseExceptions // true),
                    handoffConditionTimeout: ($defaults.tuning.handoffConditionTimeout // 900000),
                    resetOffsetAutomatically: ($defaults.tuning.resetOffsetAutomatically // false),
                    workerThreads: null,
                    chatThreads: null,
                    chatRetries: ($defaults.tuning.chatRetries // 8),
                    httpTimeout: ($defaults.tuning.httpTimeout // "PT10S"),
                    shutdownTimeout: ($defaults.tuning.shutdownTimeout // "PT80S"),
                    offsetFetchPeriod: ($defaults.tuning.offsetFetchPeriod // "PT30S"),
                    intermediateHandoffPeriod: ($defaults.tuning.intermediateHandoffPeriod // "P2147483647D"),
                    logParseExceptions: ($defaults.tuning.logParseExceptions // true),
                    maxParseExceptions: ($defaults.tuning.maxParseExceptions // 10000),
                    maxSavedParseExceptions: ($defaults.tuning.maxSavedParseExceptions // 100),
                    skipSequenceNumberAvailabilityCheck: ($defaults.tuning.skipSequenceNumberAvailabilityCheck // false),
                    partitionsSpec: {
                        type: ($defaults.tuning.partitionsSpecType // "dynamic"),
                        partitionDimensions: ($defaults.tuning.secondaryPartitionDimensions // []),
                        targetRowsPerSegment: ($defaults.tuning.targetRowsPerSegment // 5000000)
                    },
                    splitHintSpec: {
                        type: "maxSize",
                        maxSplitSize: ($defaults.tuning.maxSplitSize // 1073741824),
                        maxInputSegmentBytesPerTask: ($defaults.tuning.maxInputSegmentBytesPerTask // 10737418240)
                    },
                    indexSpec: {
                        bitmap: {
                            type: ($schema.indexSpec.bitmapType // "roaring")
                        },
                        dimensionCompression: ($schema.indexSpec.dimensionCompression // "lz4"),
                        metricCompression: ($schema.indexSpec.metricCompression // "lz4"),
                        longEncoding: ($schema.indexSpec.longEncoding // "longs")
                    },
                    indexSpecForIntermediatePersists: {
                        bitmap: {
                            type: ($schema.indexSpec.bitmapType // "roaring")
                        },
                        dimensionCompression: ($schema.indexSpec.dimensionCompression // "lz4"),
                        metricCompression: ($schema.indexSpec.metricCompression // "lz4"),
                        longEncoding: ($schema.indexSpec.longEncoding // "longs")
                    }
                },
                dataSchema: {
                    dataSource: $datasource,
                    timestampSpec: {
                        column: ($defaults.druid.timestampColumn // "settlementTimestampMs"),
                        format: ($defaults.druid.timestampFormat // "millis"),
                        missingValue: null
                    },
                    dimensionsSpec: build_dimensions,
                    metricsSpec: build_metrics,
                    transformSpec: build_transforms,
                    granularitySpec: {
                        type: "uniform",
                        segmentGranularity: ($defaults.granularity.segmentGranularity // "DAY"),
                        queryGranularity: ($defaults.granularity.queryGranularity // "NONE"),
                        rollup: ($defaults.granularity.rollup // false),
                        intervals: null
                    }
                }
            }
        }
        ' > "$output"
    
    log_info "Supervisor spec built successfully: $output"
    echo "$output"
}

# Deploy supervisor
deploy_spec() {
    local env="$1"
    
    log_info "Deploying supervisor for environment: $env"
    
    load_config "$env"
    
    # Validate Druid URL
    if [ -z "$DRUID_URL" ]; then
        error_exit "DRUID_URL is required. Set it in ${CONFIG_DIR}/${env}.env"
    fi
    
    if [[ ! "$DRUID_URL" =~ ^https?:// ]]; then
        error_exit "Invalid DRUID_URL: $DRUID_URL (must start with http:// or https://)"
    fi
    
    # Build spec if not exists
    local spec_file="${SPECS_DIR}/supervisor-spec-${DATASOURCE}-${env}.json"
    if [ ! -f "$spec_file" ]; then
        log_info "Spec file not found, building it first..."
        build_spec "$env" "$spec_file"
    fi
    
    # Deploy to Druid
    local url="${DRUID_URL}/druid/indexer/v1/supervisor"
    log_info "Posting spec to: $url"
    
    local response
    local http_code
    
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d @"$spec_file" \
        "$url") || error_exit "Failed to connect to Druid Overlord: $url"
    
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        log_info "Supervisor deployed successfully for datasource: $DATASOURCE"
        echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
    else
        error_exit "Deployment failed (HTTP $http_code): $response_body"
    fi
}

# Get supervisor status
get_status() {
    local env="$1"
    
    log_info "Getting supervisor status for environment: $env"
    
    load_config "$env"
    
    # Validate Druid URL
    if [ -z "$DRUID_URL" ]; then
        error_exit "DRUID_URL is required. Set it in ${CONFIG_DIR}/${env}.env"
    fi
    
    local url="${DRUID_URL}/druid/indexer/v1/supervisor/${DATASOURCE}/status"
    log_info "Fetching status from: $url"
    
    local response
    local http_code
    
    response=$(curl -s -w "\n%{http_code}" \
        -X GET \
        -H "Accept: application/json" \
        "$url") || error_exit "Failed to connect to Druid Overlord: $url"
    
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
    else
        error_exit "Failed to get status (HTTP $http_code): $response_body"
    fi
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
    check_prerequisites
    
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
            
            build_spec "$env" "$output"
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
            
            deploy_spec "$env"
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
            
            get_status "$env"
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

