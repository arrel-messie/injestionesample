package com.company.druid.config;

import com.company.druid.schema.record.Schema;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import com.typesafe.config.ConfigFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

/**
 * Configuration record containing all Druid supervisor settings
 * Organized into logical sub-configurations for better maintainability
 * 
 * @param kafka Kafka consumer configuration
 * @param protobuf Protobuf descriptor and message type configuration
 * @param druid Druid cluster and datasource configuration
 * @param task Task execution configuration
 * @param tuning Performance tuning configuration
 * @param granularity Time granularity configuration
 * @param schema Schema definition (dimensions, metrics, transforms, indexSpec)
 */
public record Config(
    KafkaConfig kafka,
    ProtobufConfig protobuf,
    DruidConfig druid,
    TaskConfig task,
    TuningConfig tuning,
    GranularityConfig granularity,
    Schema schema
) {
    private static final Logger log = LoggerFactory.getLogger(Config.class);
    private static final ObjectMapper YAML_MAPPER = new ObjectMapper(new YAMLFactory());
    
    /**
     * Load configuration from files and system properties
     * Uses automatic mapping from Typesafe Config to sub-configurations
     * @throws com.company.druid.exceptions.ConfigException if schema.yml is missing or invalid
     */
    public static Config load(Path moduleRoot, String env) throws com.company.druid.exceptions.ConfigException {
        var cfg = loadTypesafeConfig(moduleRoot, env);
        var schema = com.company.druid.schema.SchemaLoader.load(moduleRoot);
        
        try {
            return new Config(
                cfg.hasPath("kafka") ? mapConfig(cfg.getConfig("kafka"), KafkaConfig.class) : KafkaConfig.defaults(),
                cfg.hasPath("protobuf") ? mapConfig(cfg.getConfig("protobuf"), ProtobufConfig.class) : ProtobufConfig.defaults(),
                cfg.hasPath("druid") ? mapConfig(cfg.getConfig("druid"), DruidConfig.class) : DruidConfig.defaults(),
                cfg.hasPath("task") ? mapConfig(cfg.getConfig("task"), TaskConfig.class) : TaskConfig.defaults(),
                cfg.hasPath("tuning") ? mapConfig(cfg.getConfig("tuning"), TuningConfig.class) : TuningConfig.defaults(),
                cfg.hasPath("granularity") ? mapConfig(cfg.getConfig("granularity"), GranularityConfig.class) : GranularityConfig.defaults(),
                schema
            );
        } catch (Exception e) {
            throw new com.company.druid.exceptions.ConfigException("Failed to load configuration: " + e.getMessage(), e);
        }
    }
    
    /**
     * Maps Typesafe Config to a record using Jackson
     */
    private static <T> T mapConfig(com.typesafe.config.Config cfg, Class<T> clazz) {
        try {
            var json = cfg.root().render(com.typesafe.config.ConfigRenderOptions.concise());
            return YAML_MAPPER.readValue(json, clazz);
        } catch (Exception e) {
            log.warn("Failed to map config to {}, using defaults", clazz.getSimpleName(), e);
            return getDefaults(clazz);
        }
    }
    
    @SuppressWarnings("unchecked")
    private static <T> T getDefaults(Class<T> clazz) {
        if (clazz == KafkaConfig.class) return (T) KafkaConfig.defaults();
        if (clazz == ProtobufConfig.class) return (T) ProtobufConfig.defaults();
        if (clazz == DruidConfig.class) return (T) DruidConfig.defaults();
        if (clazz == TaskConfig.class) return (T) TaskConfig.defaults();
        if (clazz == TuningConfig.class) return (T) TuningConfig.defaults();
        if (clazz == GranularityConfig.class) return (T) GranularityConfig.defaults();
        throw new IllegalArgumentException("Unknown config type: " + clazz);
    }
    
    private static com.typesafe.config.Config loadTypesafeConfig(Path moduleRoot, String env) {
        var defaultsFile = moduleRoot.resolve("config/defaults.yml");
        var envFile = moduleRoot.resolve("config/" + env + ".env");
        
        var defaults = Files.exists(defaultsFile)
            ? ConfigFactory.parseFileAnySyntax(defaultsFile.toFile())
            : ConfigFactory.empty();
        
        var envConfig = Files.exists(envFile)
            ? ConfigFactory.parseFile(envFile.toFile(), com.typesafe.config.ConfigParseOptions.defaults()
                .setSyntax(com.typesafe.config.ConfigSyntax.PROPERTIES))
            : ConfigFactory.empty();
        
        return ConfigFactory.systemProperties()
            .withFallback(ConfigFactory.systemEnvironment())
            .withFallback(envConfig)
            .withFallback(defaults)
            .resolve();
    }
    
    /**
     * Minimal default config for testing
     */
    public static Config defaults() {
        return new Config(
            KafkaConfig.defaults(),
            ProtobufConfig.defaults(),
            DruidConfig.defaults(),
            TaskConfig.defaults(),
            TuningConfig.defaults(),
            GranularityConfig.defaults(),
            Schema.defaults()
        );
    }
    
    // Sub-configuration records
    
    /**
     * Kafka consumer configuration
     */
    public record KafkaConfig(
        String bootstrapServers,
        String securityProtocol,
        String saslMechanism,
        String saslJaasConfig,
        String sslEndpointId,
        String topic,
        String autoOffsetReset,
        int fetchMinBytes,
        int fetchMaxWaitMs,
        int maxPollRecords,
        int sessionTimeoutMs,
        int heartbeatIntervalMs,
        int maxPollIntervalMs
    ) {
        public static KafkaConfig defaults() {
            return new KafkaConfig(
                "localhost:9092", "PLAINTEXT", "PLAIN", "", "", "topic", "latest",
                1_048_576, 500, 500, 30_000, 3_000, 300_000
            );
        }
    }
    
    /**
     * Protobuf descriptor and message type configuration
     */
    public record ProtobufConfig(
        String descriptorPath,
        String messageType
    ) {
        public static ProtobufConfig defaults() {
            return new ProtobufConfig(
                "file:///opt/shared/schemas/settlement_transaction.desc",
                "com.company.PaymentTransactionEvent"
            );
        }
    }
    
    /**
     * Druid cluster and datasource configuration
     */
    public record DruidConfig(
        String url,
        String datasource,
        String timestampColumn,
        String timestampFormat
    ) {
        public static DruidConfig defaults() {
            return new DruidConfig(
                "http://localhost:8888", "datasource", "settlementTimestampMs", "millis"
            );
        }
    }
    
    /**
     * Task execution configuration
     */
    public record TaskConfig(
        boolean useEarliestOffset,
        boolean useTransaction,
        int taskCount,
        int replicas,
        String taskDuration,
        String startDelay,
        String period,
        String completionTimeout,
        String lateMessageRejectionPeriod,
        int pollTimeout,
        String minimumMessageTime
    ) {
        public static TaskConfig defaults() {
            return new TaskConfig(
                false, true, 10, 2, "PT1H", "PT5S", "PT30S", "PT1H", "PT1H", 100,
                "1970-01-01T00:00:00.000Z"
            );
        }
    }
    
    /**
     * Performance tuning configuration
     */
    public record TuningConfig(
        int maxRowsInMemory,
        long maxBytesInMemory,
        int maxRowsPerSegment,
        int maxPendingPersists,
        boolean reportParseExceptions,
        long handoffConditionTimeout,
        boolean resetOffsetAutomatically,
        int chatRetries,
        String httpTimeout,
        String shutdownTimeout,
        String offsetFetchPeriod,
        String intermediateHandoffPeriod,
        boolean logParseExceptions,
        int maxParseExceptions,
        int maxSavedParseExceptions,
        boolean skipSequenceNumberAvailabilityCheck,
        String partitionsSpecType,
        List<String> secondaryPartitionDimensions,
        int targetRowsPerSegment,
        long maxSplitSize,
        long maxInputSegmentBytesPerTask
    ) {
        public static TuningConfig defaults() {
            return new TuningConfig(
                500_000, 536_870_912L, 5_000_000, 2, true, 900_000L, false, 8,
                "PT10S", "PT80S", "PT30S", "P2147483647D", true, 10_000, 100, false,
                "dynamic", List.of(), 5_000_000, 1_073_741_824L, 10_737_418_240L
            );
        }
    }
    
    /**
     * Time granularity configuration
     */
    public record GranularityConfig(
        String segmentGranularity,
        String queryGranularity,
        boolean rollup
    ) {
        public static GranularityConfig defaults() {
            return new GranularityConfig("DAY", "NONE", false);
        }
    }
}
