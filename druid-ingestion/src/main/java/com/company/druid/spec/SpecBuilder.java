package com.company.druid.spec;

import com.company.druid.config.Config;
import com.company.druid.schema.record.IndexSpec;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Builds Druid supervisor JSON specifications from configuration.
 * 
 * <p>This class constructs the complete Druid supervisor JSON specification
 * including IO configuration, tuning parameters, and data schema.
 */
public class SpecBuilder {
    private static final ObjectMapper MAPPER = new ObjectMapper();

    /**
     * Build the complete supervisor specification.
     * 
     * @param config Configuration containing all supervisor settings
     * @param env Environment name (used for Kafka consumer group ID)
     * @return Complete supervisor specification as JSON object
     */
    public ObjectNode build(Config config, String env) {
        var spec = MAPPER.createObjectNode();
        spec.put("type", "kafka");
        
        var specContent = spec.putObject("spec");
        specContent.set("ioConfig", buildIoConfig(config, env));
        specContent.set("tuningConfig", buildTuningConfig(config));
        specContent.set("dataSchema", buildDataSchema(config));
        
        return spec;
    }

    private ObjectNode buildIoConfig(Config config, String env) {
        var io = MAPPER.createObjectNode();
        io.put("type", "kafka");
        io.set("consumerProperties", buildConsumerProperties(config, env));
        io.put("topic", config.kafka().topic());
        io.set("inputFormat", buildInputFormat(config));
        
        var task = config.task();
        io.put("useEarliestOffset", task.useEarliestOffset());
        io.put("useTransaction", task.useTransaction());
        io.put("taskCount", task.taskCount());
        io.put("replicas", task.replicas());
        io.put("taskDuration", task.taskDuration());
        io.put("startDelay", task.startDelay());
        io.put("period", task.period());
        io.put("completionTimeout", task.completionTimeout());
        io.put("lateMessageRejectionPeriod", task.lateMessageRejectionPeriod());
        io.put("pollTimeout", task.pollTimeout());
        io.put("minimumMessageTime", task.minimumMessageTime());
        
        return io;
    }

    private ObjectNode buildConsumerProperties(Config config, String env) {
        var consumer = MAPPER.createObjectNode();
        var kafka = config.kafka();
        consumer.put("bootstrap.servers", kafka.bootstrapServers());
        consumer.put("security.protocol", kafka.securityProtocol());
        consumer.put("sasl.mechanism", kafka.saslMechanism());
        consumer.put("sasl.jaas.config", kafka.saslJaasConfig());
        consumer.put("ssl.endpoint.identification.algorithm", kafka.sslEndpointId());
        consumer.put("group.id", "druid-" + config.druid().datasource() + "-" + env);
        consumer.put("fetch.min.bytes", kafka.fetchMinBytes());
        consumer.put("fetch.max.wait.ms", kafka.fetchMaxWaitMs());
        consumer.put("max.poll.records", kafka.maxPollRecords());
        consumer.put("session.timeout.ms", kafka.sessionTimeoutMs());
        consumer.put("heartbeat.interval.ms", kafka.heartbeatIntervalMs());
        consumer.put("max.poll.interval.ms", kafka.maxPollIntervalMs());
        consumer.put("enable.auto.commit", false);
        consumer.put("auto.offset.reset", kafka.autoOffsetReset());
        return consumer;
    }

    private ObjectNode buildInputFormat(Config config) {
        var inputFormat = MAPPER.createObjectNode();
        inputFormat.put("type", "protobuf");
        var decoder = inputFormat.putObject("protoBytesDecoder");
        decoder.put("type", "file");
        var proto = config.protobuf();
        decoder.put("descriptor", proto.descriptorPath());
        decoder.put("protoMessageType", proto.messageType());
        return inputFormat;
    }

    private ObjectNode buildTuningConfig(Config config) {
        var t = config.tuning();
        var tuning = putAll(MAPPER.createObjectNode(),
            "type", "kafka",
            "maxRowsInMemory", t.maxRowsInMemory(),
            "maxBytesInMemory", t.maxBytesInMemory(),
            "maxRowsPerSegment", t.maxRowsPerSegment(),
            "intermediatePersistPeriod", "PT10M",
            "maxPendingPersists", t.maxPendingPersists(),
            "reportParseExceptions", t.reportParseExceptions(),
            "handoffConditionTimeout", t.handoffConditionTimeout(),
            "resetOffsetAutomatically", t.resetOffsetAutomatically(),
            "chatRetries", t.chatRetries(),
            "httpTimeout", t.httpTimeout(),
            "shutdownTimeout", t.shutdownTimeout(),
            "offsetFetchPeriod", t.offsetFetchPeriod(),
            "intermediateHandoffPeriod", t.intermediateHandoffPeriod(),
            "logParseExceptions", t.logParseExceptions(),
            "maxParseExceptions", t.maxParseExceptions(),
            "maxSavedParseExceptions", t.maxSavedParseExceptions(),
            "skipSequenceNumberAvailabilityCheck", t.skipSequenceNumberAvailabilityCheck()
        );
        tuning.putNull("maxTotalRows").putNull("workerThreads").putNull("chatThreads");
        
        tuning.set("partitionsSpec", buildPartitionsSpec(t));
        tuning.set("splitHintSpec", buildSplitHintSpec(t));
        
        var indexSpec = buildIndexSpec(config.schema().indexSpec());
        tuning.set("indexSpec", indexSpec);
        tuning.set("indexSpecForIntermediatePersists", indexSpec);
        
        return tuning;
    }
    
    private ObjectNode buildPartitionsSpec(Config.TuningConfig tuning) {
        var spec = MAPPER.createObjectNode();
        spec.put("type", tuning.partitionsSpecType());
        var dims = spec.putArray("partitionDimensions");
        tuning.secondaryPartitionDimensions().forEach(dims::add);
        spec.put("targetRowsPerSegment", tuning.targetRowsPerSegment());
        return spec;
    }
    
    private ObjectNode buildSplitHintSpec(Config.TuningConfig tuning) {
        return putAll(MAPPER.createObjectNode(),
            "type", "maxSize",
            "maxSplitSize", tuning.maxSplitSize(),
            "maxInputSegmentBytesPerTask", tuning.maxInputSegmentBytesPerTask()
        );
    }
    
    /**
     * Helper method to put multiple key-value pairs into an ObjectNode.
     * Reduces repetitive put() calls.
     */
    private ObjectNode putAll(ObjectNode node, Object... keyValues) {
        for (int i = 0; i < keyValues.length; i += 2) {
            var key = (String) keyValues[i];
            var value = keyValues[i + 1];
            if (value instanceof String s) node.put(key, s);
            else if (value instanceof Integer n) node.put(key, n);
            else if (value instanceof Long l) node.put(key, l);
            else if (value instanceof Boolean b) node.put(key, b);
        }
        return node;
    }

    private ObjectNode buildDataSchema(Config config) {
        var dataSchema = MAPPER.createObjectNode();
        var druid = config.druid();
        dataSchema.put("dataSource", druid.datasource());
        
        // Timestamp spec
        var timestampSpec = MAPPER.createObjectNode();
        timestampSpec.put("column", druid.timestampColumn());
        timestampSpec.put("format", druid.timestampFormat());
        timestampSpec.putNull("missingValue");
        dataSchema.set("timestampSpec", timestampSpec);
        
        dataSchema.set("dimensionsSpec", buildDimensionsSpec(config));
        dataSchema.set("metricsSpec", buildMetricsSpec(config));
        dataSchema.set("transformSpec", buildTransformSpec(config));
        dataSchema.set("granularitySpec", buildGranularitySpec(config));
        
        return dataSchema;
    }

    private ObjectNode buildDimensionsSpec(Config config) {
        var spec = MAPPER.createObjectNode();
        var dims = spec.putArray("dimensions");
        config.schema().dimensions().forEach(d -> {
            var dim = MAPPER.createObjectNode();
            dim.put("type", d.type());
            dim.put("name", d.name());
            dims.add(dim);
        });
        var exclusions = spec.putArray("dimensionExclusions");
        exclusions.add("settlement_ts").add("settlement_entry_ts").add("acceptance_ts").add("payee_access_manager_id");
        spec.put("includeAllDimensions", false);
        spec.put("useSchemaDiscovery", false);
        return spec;
    }

    private ArrayNode buildMetricsSpec(Config config) {
        var metrics = MAPPER.createArrayNode();
        config.schema().metrics().forEach(m -> {
            var metric = MAPPER.createObjectNode();
            metric.put("type", m.type());
            metric.put("name", m.name());
            if (m.fieldName() != null) {
                metric.put("fieldName", m.fieldName());
            }
            metrics.add(metric);
        });
        return metrics;
    }

    private ObjectNode buildTransformSpec(Config config) {
        var spec = MAPPER.createObjectNode();
        var transforms = spec.putArray("transforms");
        config.schema().transforms().forEach(t -> {
            var transform = MAPPER.createObjectNode();
            transform.put("type", "expression");
            transform.put("name", t.name());
            transform.put("expression", t.expression());
            transforms.add(transform);
        });
        spec.putNull("filter");
        return spec;
    }

    private ObjectNode buildGranularitySpec(Config config) {
        var spec = MAPPER.createObjectNode();
        spec.put("type", "uniform");
        var g = config.granularity();
        spec.put("segmentGranularity", g.segmentGranularity());
        spec.put("queryGranularity", g.queryGranularity());
        spec.put("rollup", g.rollup());
        spec.putNull("intervals");
        return spec;
    }

    private ObjectNode buildIndexSpec(IndexSpec indexSpec) {
        var spec = MAPPER.createObjectNode();
        var bitmap = spec.putObject("bitmap");
        bitmap.put("type", indexSpec.bitmapType());
        spec.put("dimensionCompression", indexSpec.dimensionCompression());
        spec.put("metricCompression", indexSpec.metricCompression());
        spec.put("longEncoding", indexSpec.longEncoding());
        return spec;
    }
}
