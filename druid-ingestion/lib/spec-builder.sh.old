#!/usr/bin/env bash
#
# Spec Builder module - Builds Druid supervisor spec from template and schema
#

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validator.sh"

# Build dimensions spec from schema.yml
_build_dimensions_spec() {
    local schema_file="$1"
    
    if ! command -v jq >/dev/null 2>&1 && ! command -v yq >/dev/null 2>&1; then
        log_error "jq or yq is required to build dimensions spec"
        return 1
    fi
    
    if command -v jq >/dev/null 2>&1; then
        # Convert YAML to JSON and extract dimensions
        if command -v yq >/dev/null 2>&1; then
            yq eval -o=json "$schema_file" | jq -c '{
                dimensions: (.dimensions // []),
                dimensionExclusions: ["settlement_ts", "settlement_entry_ts", "acceptance_ts", "payee_access_manager_id"],
                includeAllDimensions: false,
                useSchemaDiscovery: false
            }'
        else
            # Fallback: use Python to convert YAML to JSON
            python3 -c "
import yaml
import json
with open('$schema_file', 'r') as f:
    schema = yaml.safe_load(f)
    dimensions = schema.get('dimensions', [])
    result = {
        'dimensions': dimensions,
        'dimensionExclusions': ['settlement_ts', 'settlement_entry_ts', 'acceptance_ts', 'payee_access_manager_id'],
        'includeAllDimensions': False,
        'useSchemaDiscovery': False
    }
    print(json.dumps(result, separators=(',', ':')))
" 2>/dev/null
        fi
    else
        log_error "jq is required for building dimensions spec"
        return 1
    fi
}

# Build metrics spec from schema.yml
_build_metrics_spec() {
    local schema_file="$1"
    
    if command -v jq >/dev/null 2>&1; then
        if command -v yq >/dev/null 2>&1; then
            yq eval -o=json "$schema_file" | jq -c '.metrics // []'
        else
            python3 -c "
import yaml
import json
with open('$schema_file', 'r') as f:
    schema = yaml.safe_load(f)
    print(json.dumps(schema.get('metrics', []), separators=(',', ':')))
" 2>/dev/null
        fi
    else
        log_error "jq is required for building metrics spec"
        return 1
    fi
}

# Build transforms spec from schema.yml
_build_transforms_spec() {
    local schema_file="$1"
    
    if command -v jq >/dev/null 2>&1; then
        if command -v yq >/dev/null 2>&1; then
            yq eval -o=json "$schema_file" | jq -c '{
                transforms: ((.transforms // []) | map({
                    type: "expression",
                    name: .name,
                    expression: .expression
                })),
                filter: null
            }'
        else
            python3 -c "
import yaml
import json
with open('$schema_file', 'r') as f:
    schema = yaml.safe_load(f)
    transforms = schema.get('transforms', [])
    result = {
        'transforms': [{'type': 'expression', 'name': t['name'], 'expression': t['expression']} for t in transforms],
        'filter': None
    }
    print(json.dumps(result, separators=(',', ':')))
" 2>/dev/null
        fi
    else
        log_error "jq is required for building transforms spec"
        return 1
    fi
}

# Load index spec from schema.yml
_load_index_spec() {
    local schema_file="$1"
    
    if command -v yq >/dev/null 2>&1; then
        export INDEX_SPEC_BITMAP_TYPE="$(yq eval '.indexSpec.bitmapType' "$schema_file" 2>/dev/null || echo "roaring")"
        export INDEX_SPEC_DIMENSION_COMPRESSION="$(yq eval '.indexSpec.dimensionCompression' "$schema_file" 2>/dev/null || echo "lz4")"
        export INDEX_SPEC_METRIC_COMPRESSION="$(yq eval '.indexSpec.metricCompression' "$schema_file" 2>/dev/null || echo "lz4")"
        export INDEX_SPEC_LONG_ENCODING="$(yq eval '.indexSpec.longEncoding' "$schema_file" 2>/dev/null || echo "longs")"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import yaml
import os
with open('$schema_file', 'r') as f:
    schema = yaml.safe_load(f)
    index_spec = schema.get('indexSpec', {})
    os.environ['INDEX_SPEC_BITMAP_TYPE'] = index_spec.get('bitmapType', 'roaring')
    os.environ['INDEX_SPEC_DIMENSION_COMPRESSION'] = index_spec.get('dimensionCompression', 'lz4')
    os.environ['INDEX_SPEC_METRIC_COMPRESSION'] = index_spec.get('metricCompression', 'lz4')
    os.environ['INDEX_SPEC_LONG_ENCODING'] = index_spec.get('longEncoding', 'longs')
" 2>/dev/null
        source <(python3 -c "
import yaml
import os
with open('$schema_file', 'r') as f:
    schema = yaml.safe_load(f)
    index_spec = schema.get('indexSpec', {})
    print('export INDEX_SPEC_BITMAP_TYPE={}'.format(index_spec.get('bitmapType', 'roaring')))
    print('export INDEX_SPEC_DIMENSION_COMPRESSION={}'.format(index_spec.get('dimensionCompression', 'lz4')))
    print('export INDEX_SPEC_METRIC_COMPRESSION={}'.format(index_spec.get('metricCompression', 'lz4')))
    print('export INDEX_SPEC_LONG_ENCODING={}'.format(index_spec.get('longEncoding', 'longs')))
" 2>/dev/null)
    else
        log_warn "yq or python3 not found, using defaults for index spec"
        export INDEX_SPEC_BITMAP_TYPE="roaring"
        export INDEX_SPEC_DIMENSION_COMPRESSION="lz4"
        export INDEX_SPEC_METRIC_COMPRESSION="lz4"
        export INDEX_SPEC_LONG_ENCODING="longs"
    fi
}

# Build supervisor spec from template
build_spec() {
    local env="${1:-}"
    local output="${2:-}"
    local config_dir="${3:-}"
    local template_dir="${4:-}"
    
    if [ -z "$env" ]; then
        log_error "Environment is required"
        return 1
    fi
    
    export ENV="$env"
    
    local schema_file="${config_dir}/schema.yml"
    if ! validate_file_exists "$schema_file" "Schema"; then
        return 1
    fi
    
    local template_file="${template_dir}/supervisor-spec.json.template"
    if ! validate_file_exists "$template_file" "Template"; then
        return 1
    fi
    
    # Load index spec from schema
    _load_index_spec "$schema_file"
    
    # Build schema components
    local dimensions_spec
    local metrics_spec
    local transforms_spec
    
    dimensions_spec=$(_build_dimensions_spec "$schema_file") || return 1
    metrics_spec=$(_build_metrics_spec "$schema_file") || return 1
    transforms_spec=$(_build_transforms_spec "$schema_file") || return 1
    
    export DIMENSIONS_SPEC="$dimensions_spec"
    export METRICS_SPEC="$metrics_spec"
    export TRANSFORM_SPEC="$transforms_spec"
    
    # Determine output file
    if [ -z "$output" ]; then
        local specs_dir="$(dirname "$(dirname "$config_dir")")/druid-specs/generated"
        mkdir -p "$specs_dir"
        output="${specs_dir}/supervisor-spec-${DATASOURCE}-${env}.json"
    else
        mkdir -p "$(dirname "$output")"
    fi
    
    log_info "Building supervisor spec: $output"
    
    # Build spec using jq for proper JSON handling
    # Convert template to JSON and merge with actual values
    if command -v jq >/dev/null 2>&1; then
        # Convert YAML schema to JSON if needed
        local schema_json
        if command -v yq >/dev/null 2>&1; then
            schema_json=$(yq eval -o=json "$schema_file" 2>/dev/null)
        else
            # Fallback: use Python
            schema_json=$(python3 -c "
import yaml
import json
with open('$schema_file', 'r') as f:
    print(json.dumps(yaml.safe_load(f)))
" 2>/dev/null)
        fi
        
        # Build complete spec using jq with environment variables
        # Export all needed vars for jq to access via env()
        export KAFKA_FETCH_MIN_BYTES KAFKA_FETCH_MAX_WAIT_MS KAFKA_MAX_POLL_RECORDS
        export KAFKA_SESSION_TIMEOUT_MS KAFKA_HEARTBEAT_INTERVAL_MS KAFKA_MAX_POLL_INTERVAL_MS
        export KAFKA_AUTO_OFFSET_RESET
        export TASK_USE_EARLIEST_OFFSET TASK_USE_TRANSACTION TASK_COUNT TASK_REPLICAS
        export TASK_DURATION TASK_START_DELAY TASK_PERIOD TASK_COMPLETION_TIMEOUT
        export TASK_LATE_MESSAGE_REJECTION_PERIOD TASK_POLL_TIMEOUT TASK_MINIMUM_MESSAGE_TIME
        export TUNING_MAX_ROWS_IN_MEMORY TUNING_MAX_BYTES_IN_MEMORY TUNING_MAX_ROWS_PER_SEGMENT
        export TUNING_MAX_PENDING_PERSISTS TUNING_REPORT_PARSE_EXCEPTIONS
        export TUNING_HANDOFF_CONDITION_TIMEOUT TUNING_RESET_OFFSET_AUTOMATICALLY
        export TUNING_CHAT_RETRIES TUNING_HTTP_TIMEOUT TUNING_SHUTDOWN_TIMEOUT
        export TUNING_OFFSET_FETCH_PERIOD TUNING_INTERMEDIATE_HANDOFF_PERIOD
        export TUNING_LOG_PARSE_EXCEPTIONS TUNING_MAX_PARSE_EXCEPTIONS
        export TUNING_MAX_SAVED_PARSE_EXCEPTIONS TUNING_SKIP_SEQUENCE_NUMBER_AVAILABILITY_CHECK
        export TUNING_PARTITIONS_SPEC_TYPE TUNING_SECONDARY_PARTITION_DIMENSIONS
        export TUNING_TARGET_ROWS_PER_SEGMENT TUNING_MAX_SPLIT_SIZE
        export TUNING_MAX_INPUT_SEGMENT_BYTES_PER_TASK
        
        echo "$schema_json" | jq -n \
            --slurpfile schema /dev/stdin \
            --arg kafka_bootstrap "$KAFKA_BOOTSTRAP_SERVERS" \
            --arg kafka_topic "$KAFKA_TOPIC" \
            --arg kafka_security_protocol "$KAFKA_SECURITY_PROTOCOL" \
            --arg kafka_sasl_mechanism "$KAFKA_SASL_MECHANISM" \
            --arg kafka_sasl_jaas_config "$KAFKA_SASL_JAAS_CONFIG" \
            --arg kafka_ssl_endpoint_id "${KAFKA_SSL_ENDPOINT_ID:-}" \
            --arg datasource "$DATASOURCE" \
            --arg env "$ENV" \
            --arg proto_descriptor "$PROTO_DESCRIPTOR_PATH" \
            --arg proto_message_type "$PROTO_MESSAGE_TYPE" \
            --argjson dimensions_spec "$dimensions_spec" \
            --argjson metrics_spec "$metrics_spec" \
            --argjson transforms_spec "$transforms_spec" \
            --arg timestamp_column "$DRUID_TIMESTAMP_COLUMN" \
            --arg timestamp_format "$DRUID_TIMESTAMP_FORMAT" \
            --arg segment_granularity "$GRANULARITY_SEGMENT" \
            --arg query_granularity "$GRANULARITY_QUERY" \
            --argjson rollup "${GRANULARITY_ROLLUP}" \
            '
            $schema[0] as $s |
            {
                type: "kafka",
                spec: {
                    ioConfig: {
                        type: "kafka",
                        consumerProperties: {
                            "bootstrap.servers": $kafka_bootstrap,
                            "security.protocol": $kafka_security_protocol,
                            "sasl.mechanism": $kafka_sasl_mechanism,
                            "sasl.jaas.config": $kafka_sasl_jaas_config,
                            "ssl.endpoint.identification.algorithm": (if $kafka_ssl_endpoint_id == "" then "" else $kafka_ssl_endpoint_id end),
                            "group.id": "druid-\($datasource)-\($env)",
                            "fetch.min.bytes": (env.KAFKA_FETCH_MIN_BYTES // "1048576" | tonumber),
                            "fetch.max.wait.ms": (env.KAFKA_FETCH_MAX_WAIT_MS // "500" | tonumber),
                            "max.poll.records": (env.KAFKA_MAX_POLL_RECORDS // "500" | tonumber),
                            "session.timeout.ms": (env.KAFKA_SESSION_TIMEOUT_MS // "30000" | tonumber),
                            "heartbeat.interval.ms": (env.KAFKA_HEARTBEAT_INTERVAL_MS // "3000" | tonumber),
                            "max.poll.interval.ms": (env.KAFKA_MAX_POLL_INTERVAL_MS // "300000" | tonumber),
                            "enable.auto.commit": false,
                            "auto.offset.reset": (env.KAFKA_AUTO_OFFSET_RESET // "latest")
                        },
                        topic: $kafka_topic,
                        inputFormat: {
                            type: "protobuf",
                            protoBytesDecoder: {
                                type: "file",
                                descriptor: $proto_descriptor,
                                protoMessageType: $proto_message_type
                            }
                        },
                        useEarliestOffset: (env.TASK_USE_EARLIEST_OFFSET // "false" | test("true")),
                        useTransaction: (env.TASK_USE_TRANSACTION // "true" | test("true")),
                        taskCount: (env.TASK_COUNT // "10" | tonumber),
                        replicas: (env.TASK_REPLICAS // "2" | tonumber),
                        taskDuration: (env.TASK_DURATION // "PT1H"),
                        startDelay: (env.TASK_START_DELAY // "PT5S"),
                        period: (env.TASK_PERIOD // "PT30S"),
                        completionTimeout: (env.TASK_COMPLETION_TIMEOUT // "PT1H"),
                        lateMessageRejectionPeriod: (env.TASK_LATE_MESSAGE_REJECTION_PERIOD // "PT1H"),
                        pollTimeout: (env.TASK_POLL_TIMEOUT // "100" | tonumber),
                        minimumMessageTime: (env.TASK_MINIMUM_MESSAGE_TIME // "1970-01-01T00:00:00.000Z")
                    },
                    tuningConfig: {
                        type: "kafka",
                        maxRowsInMemory: (env.TUNING_MAX_ROWS_IN_MEMORY // "500000" | tonumber),
                        maxBytesInMemory: (env.TUNING_MAX_BYTES_IN_MEMORY // "536870912" | tonumber),
                        maxRowsPerSegment: (env.TUNING_MAX_ROWS_PER_SEGMENT // "5000000" | tonumber),
                        maxTotalRows: null,
                        intermediatePersistPeriod: "PT10M",
                        maxPendingPersists: (env.TUNING_MAX_PENDING_PERSISTS // "2" | tonumber),
                        reportParseExceptions: (env.TUNING_REPORT_PARSE_EXCEPTIONS // "true" | test("true")),
                        handoffConditionTimeout: (env.TUNING_HANDOFF_CONDITION_TIMEOUT // "900000" | tonumber),
                        resetOffsetAutomatically: (env.TUNING_RESET_OFFSET_AUTOMATICALLY // "false" | test("true")),
                        workerThreads: null,
                        chatThreads: null,
                        chatRetries: (env.TUNING_CHAT_RETRIES // "8" | tonumber),
                        httpTimeout: (env.TUNING_HTTP_TIMEOUT // "PT10S"),
                        shutdownTimeout: (env.TUNING_SHUTDOWN_TIMEOUT // "PT80S"),
                        offsetFetchPeriod: (env.TUNING_OFFSET_FETCH_PERIOD // "PT30S"),
                        intermediateHandoffPeriod: (env.TUNING_INTERMEDIATE_HANDOFF_PERIOD // "P2147483647D"),
                        logParseExceptions: (env.TUNING_LOG_PARSE_EXCEPTIONS // "true" | test("true")),
                        maxParseExceptions: (env.TUNING_MAX_PARSE_EXCEPTIONS // "10000" | tonumber),
                        maxSavedParseExceptions: (env.TUNING_MAX_SAVED_PARSE_EXCEPTIONS // "100" | tonumber),
                        skipSequenceNumberAvailabilityCheck: (env.TUNING_SKIP_SEQUENCE_NUMBER_AVAILABILITY_CHECK // "false" | test("true")),
                        partitionsSpec: {
                            type: (env.TUNING_PARTITIONS_SPEC_TYPE // "dynamic"),
                            partitionDimensions: (try (env.TUNING_SECONDARY_PARTITION_DIMENSIONS | fromjson) catch []),
                            targetRowsPerSegment: (env.TUNING_TARGET_ROWS_PER_SEGMENT // "5000000" | tonumber)
                        },
                        splitHintSpec: {
                            type: "maxSize",
                            maxSplitSize: (env.TUNING_MAX_SPLIT_SIZE // "1073741824" | tonumber),
                            maxInputSegmentBytesPerTask: (env.TUNING_MAX_INPUT_SEGMENT_BYTES_PER_TASK // "10737418240" | tonumber)
                        },
                        indexSpec: {
                            bitmap: {
                                type: ($s.indexSpec.bitmapType // "roaring")
                            },
                            dimensionCompression: ($s.indexSpec.dimensionCompression // "lz4"),
                            metricCompression: ($s.indexSpec.metricCompression // "lz4"),
                            longEncoding: ($s.indexSpec.longEncoding // "longs")
                        },
                        indexSpecForIntermediatePersists: {
                            bitmap: {
                                type: ($s.indexSpec.bitmapType // "roaring")
                            },
                            dimensionCompression: ($s.indexSpec.dimensionCompression // "lz4"),
                            metricCompression: ($s.indexSpec.metricCompression // "lz4"),
                            longEncoding: ($s.indexSpec.longEncoding // "longs")
                        }
                    },
                    dataSchema: {
                        dataSource: $datasource,
                        timestampSpec: {
                            column: $timestamp_column,
                            format: $timestamp_format,
                            missingValue: null
                        },
                        dimensionsSpec: $dimensions_spec,
                        metricsSpec: $metrics_spec,
                        transformSpec: $transforms_spec,
                        granularitySpec: {
                            type: "uniform",
                            segmentGranularity: $segment_granularity,
                            queryGranularity: $query_granularity,
                            rollup: $rollup,
                            intervals: null
                        }
                    }
                }
            }
            ' > "$output" 2>/dev/null || {
            log_error "Failed to build spec with jq"
            return 1
        }
    else
        log_error "jq is required for building spec"
        return 1
    fi
    
    # Validate generated JSON
    if command -v jq >/dev/null 2>&1; then
        if ! jq empty "$output" 2>/dev/null; then
            log_error "Generated spec is not valid JSON"
            return 1
        fi
    fi
    
    log_info "Supervisor spec built successfully: $output"
    echo "$output"
}

