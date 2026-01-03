package com.company.druid;

import java.util.List;

/**
 * Configuration record containing all Druid supervisor settings
 */
public record Config(
    // Kafka
    String kafkaBootstrapServers,
    String kafkaSecurityProtocol,
    String kafkaSaslMechanism,
    String kafkaSaslJaasConfig,
    String kafkaSslEndpointId,
    String kafkaTopic,
    String kafkaAutoOffsetReset,
    int kafkaFetchMinBytes,
    int kafkaFetchMaxWaitMs,
    int kafkaMaxPollRecords,
    int kafkaSessionTimeoutMs,
    int kafkaHeartbeatIntervalMs,
    int kafkaMaxPollIntervalMs,
    
    // Protobuf
    String protoDescriptorPath,
    String protoMessageType,
    
    // Druid
    String druidUrl,
    String datasource,
    String timestampColumn,
    String timestampFormat,
    
    // Task config
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
    String minimumMessageTime,
    
    // Tuning
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
    long maxInputSegmentBytesPerTask,
    
    // Granularity
    String segmentGranularity,
    String queryGranularity,
    boolean rollup,
    
    // Schema (dimensions, metrics, transforms, indexSpec)
    Schema schema
) {
    /**
     * Default configuration values
     */
    public static Config defaults() {
        return new Config(
            "localhost:9092", "PLAINTEXT", "PLAIN", "", "",
            "topic", "latest",
            1048576, 500, 500, 30000, 3000, 300000,
            "file:///opt/shared/schemas/settlement_transaction.desc",
            "com.company.PaymentTransactionEvent",
            "http://localhost:8888", "datasource",
            "settlementTimestampMs", "millis",
            false, true, 10, 2,
            "PT1H", "PT5S", "PT30S", "PT1H", "PT1H",
            100, "1970-01-01T00:00:00.000Z",
            500000, 536870912L, 5000000, 2,
            true, 900000L, false, 8,
            "PT10S", "PT80S", "PT30S", "P2147483647D",
            true, 10000, 100, false,
            "dynamic", List.of(), 5000000,
            1073741824L, 10737418240L,
            "DAY", "NONE", false,
            SchemaLoader.defaults()
        );
    }
}
