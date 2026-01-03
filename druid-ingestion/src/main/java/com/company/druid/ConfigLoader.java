package com.company.druid;

import com.company.druid.exceptions.ConfigException;
import com.typesafe.config.Config;
import com.typesafe.config.ConfigFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.file.Path;

/**
 * Loads and validates configuration from environment files
 * Uses ConfigBuilder to reduce repetitive get() calls
 */
public class ConfigLoader {
    private static final Logger log = LoggerFactory.getLogger(ConfigLoader.class);
    private static final Config EMPTY = ConfigFactory.empty();

    /**
     * Load configuration for the specified environment and datasource
     * @param moduleRoot Root directory of the module
     * @param env Environment name (dev, staging, prod)
     * @param datasourceName Optional datasource name override (null = use default from config)
     * @throws ConfigException if configuration is invalid
     */
    public com.company.druid.Config load(Path moduleRoot, String env, String datasourceName) throws ConfigException {
        return loadInternal(moduleRoot, env, datasourceName);
    }
    
    /**
     * Backward compatibility: load without datasource name
     */
    public com.company.druid.Config load(Path moduleRoot, String env) throws ConfigException {
        return loadInternal(moduleRoot, env, null);
    }
    
    private com.company.druid.Config loadInternal(Path moduleRoot, String env, String datasourceName) throws ConfigException {
        try {
            // Try datasource-specific config first, then fallback to env config
            var configFile = datasourceName != null 
                ? moduleRoot.resolve("config/" + datasourceName + "-" + env + ".env")
                : moduleRoot.resolve("config/" + env + ".env");
            
            var cfg = loadConfig(configFile);
            var schema = SchemaLoader.load(moduleRoot, env, datasourceName);
            var builder = new ConfigBuilder(cfg);
            
            // Override datasource name if provided
            var finalDatasource = datasourceName != null ? datasourceName 
                : builder.str("DATASOURCE_NAME", com.company.druid.Config::datasource);
            
            return new com.company.druid.Config(
                builder.str("KAFKA_BOOTSTRAP_SERVERS", com.company.druid.Config::kafkaBootstrapServers),
                builder.str("KAFKA_SECURITY_PROTOCOL", com.company.druid.Config::kafkaSecurityProtocol),
                builder.str("KAFKA_SASL_MECHANISM", com.company.druid.Config::kafkaSaslMechanism),
                builder.str("KAFKA_SASL_JAAS_CONFIG", com.company.druid.Config::kafkaSaslJaasConfig),
                builder.str("KAFKA_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM", com.company.druid.Config::kafkaSslEndpointId),
                builder.str("KAFKA_TOPIC", com.company.druid.Config::kafkaTopic),
                builder.str("KAFKA_AUTO_OFFSET_RESET", com.company.druid.Config::kafkaAutoOffsetReset),
                builder.num("KAFKA_FETCH_MIN_BYTES", com.company.druid.Config::kafkaFetchMinBytes),
                builder.num("KAFKA_FETCH_MAX_WAIT_MS", com.company.druid.Config::kafkaFetchMaxWaitMs),
                builder.num("KAFKA_MAX_POLL_RECORDS", com.company.druid.Config::kafkaMaxPollRecords),
                builder.num("KAFKA_SESSION_TIMEOUT_MS", com.company.druid.Config::kafkaSessionTimeoutMs),
                builder.num("KAFKA_HEARTBEAT_INTERVAL_MS", com.company.druid.Config::kafkaHeartbeatIntervalMs),
                builder.num("KAFKA_MAX_POLL_INTERVAL_MS", com.company.druid.Config::kafkaMaxPollIntervalMs),
                builder.str("PROTO_DESCRIPTOR_PATH", com.company.druid.Config::protoDescriptorPath),
                builder.str("PROTO_MESSAGE_TYPE", com.company.druid.Config::protoMessageType),
                builder.str("DRUID_OVERLORD_URL", com.company.druid.Config::druidUrl),
                finalDatasource,
                builder.str("TIMESTAMP_COLUMN", com.company.druid.Config::timestampColumn),
                builder.str("TIMESTAMP_FORMAT", com.company.druid.Config::timestampFormat),
                builder.bool("USE_EARLIEST_OFFSET", com.company.druid.Config::useEarliestOffset),
                builder.bool("USE_TRANSACTION", com.company.druid.Config::useTransaction),
                builder.num("TASK_COUNT", com.company.druid.Config::taskCount),
                builder.num("REPLICAS", com.company.druid.Config::replicas),
                builder.str("TASK_DURATION", com.company.druid.Config::taskDuration),
                builder.str("START_DELAY", com.company.druid.Config::startDelay),
                builder.str("PERIOD", com.company.druid.Config::period),
                builder.str("COMPLETION_TIMEOUT", com.company.druid.Config::completionTimeout),
                builder.str("LATE_MESSAGE_REJECTION_PERIOD", com.company.druid.Config::lateMessageRejectionPeriod),
                builder.num("POLL_TIMEOUT", com.company.druid.Config::pollTimeout),
                builder.str("MINIMUM_MESSAGE_TIME", com.company.druid.Config::minimumMessageTime),
                builder.num("MAX_ROWS_IN_MEMORY", com.company.druid.Config::maxRowsInMemory),
                builder.lng("MAX_BYTES_IN_MEMORY", com.company.druid.Config::maxBytesInMemory),
                builder.num("MAX_ROWS_PER_SEGMENT", com.company.druid.Config::maxRowsPerSegment),
                builder.num("MAX_PENDING_PERSISTS", com.company.druid.Config::maxPendingPersists),
                builder.bool("REPORT_PARSE_EXCEPTIONS", com.company.druid.Config::reportParseExceptions),
                builder.lng("HANDOFF_CONDITION_TIMEOUT", com.company.druid.Config::handoffConditionTimeout),
                builder.bool("RESET_OFFSET_AUTOMATICALLY", com.company.druid.Config::resetOffsetAutomatically),
                builder.num("CHAT_RETRIES", com.company.druid.Config::chatRetries),
                builder.str("HTTP_TIMEOUT", com.company.druid.Config::httpTimeout),
                builder.str("SHUTDOWN_TIMEOUT", com.company.druid.Config::shutdownTimeout),
                builder.str("OFFSET_FETCH_PERIOD", com.company.druid.Config::offsetFetchPeriod),
                builder.str("INTERMEDIATE_HANDOFF_PERIOD", com.company.druid.Config::intermediateHandoffPeriod),
                builder.bool("LOG_PARSE_EXCEPTIONS", com.company.druid.Config::logParseExceptions),
                builder.num("MAX_PARSE_EXCEPTIONS", com.company.druid.Config::maxParseExceptions),
                builder.num("MAX_SAVED_PARSE_EXCEPTIONS", com.company.druid.Config::maxSavedParseExceptions),
                builder.bool("SKIP_SEQUENCE_NUMBER_AVAILABILITY_CHECK", com.company.druid.Config::skipSequenceNumberAvailabilityCheck),
                builder.str("PARTITIONS_SPEC_TYPE", com.company.druid.Config::partitionsSpecType),
                builder.list("SECONDARY_PARTITION_DIMENSIONS", com.company.druid.Config::secondaryPartitionDimensions),
                builder.num("TARGET_ROWS_PER_SEGMENT", com.company.druid.Config::targetRowsPerSegment),
                builder.lng("MAX_SPLIT_SIZE", com.company.druid.Config::maxSplitSize),
                builder.lng("MAX_INPUT_SEGMENT_BYTES_PER_TASK", com.company.druid.Config::maxInputSegmentBytesPerTask),
                builder.str("SEGMENT_GRANULARITY", com.company.druid.Config::segmentGranularity),
                builder.str("QUERY_GRANULARITY", com.company.druid.Config::queryGranularity),
                builder.bool("ROLLUP", com.company.druid.Config::rollup),
                schema
            );
        } catch (Exception e) {
            log.error("Failed to load configuration for environment: {}", env, e);
            throw new ConfigException("Failed to load configuration: " + e.getMessage(), e);
        }
    }

    private Config loadConfig(Path envFile) {
        var fileConfig = envFile.toFile().exists()
            ? ConfigFactory.parseFile(envFile.toFile(), com.typesafe.config.ConfigParseOptions.defaults()
                .setSyntax(com.typesafe.config.ConfigSyntax.PROPERTIES))
            : EMPTY;
        return fileConfig.withFallback(ConfigFactory.systemProperties())
            .withFallback(ConfigFactory.systemEnvironment()).resolve();
    }
}
