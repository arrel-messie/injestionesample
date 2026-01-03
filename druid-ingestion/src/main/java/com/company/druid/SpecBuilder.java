package com.company.druid;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Builds Druid supervisor JSON specifications
 */
public class SpecBuilder {
    private final ObjectMapper mapper = new ObjectMapper();

    /**
     * Build complete supervisor specification
     */
    public ObjectNode build(Config config, String env) {
        var spec = mapper.createObjectNode();
        spec.put("type", "kafka");

        var specContent = spec.putObject("spec");
        specContent.set("ioConfig", buildIoConfig(config, env));
        specContent.set("tuningConfig", buildTuningConfig(config));
        specContent.set("dataSchema", buildDataSchema(config));

        return spec;
    }

    private ObjectNode buildIoConfig(Config config, String env) {
        var io = mapper.createObjectNode();
        io.put("type", "kafka");
        io.set("consumerProperties", buildConsumerProperties(config, env));
        io.put("topic", config.kafkaTopic());
        io.set("inputFormat", buildInputFormat(config));
        addIoConfigSettings(io, config);
        return io;
    }

    private ObjectNode buildConsumerProperties(Config config, String env) {
        var consumer = mapper.createObjectNode();
        consumer.put("bootstrap.servers", config.kafkaBootstrapServers());
        consumer.put("security.protocol", config.kafkaSecurityProtocol());
        consumer.put("sasl.mechanism", config.kafkaSaslMechanism());
        consumer.put("sasl.jaas.config", config.kafkaSaslJaasConfig());
        consumer.put("ssl.endpoint.identification.algorithm", config.kafkaSslEndpointId());
        consumer.put("group.id", "druid-" + config.datasource() + "-" + env);
        consumer.put("fetch.min.bytes", config.kafkaFetchMinBytes());
        consumer.put("fetch.max.wait.ms", config.kafkaFetchMaxWaitMs());
        consumer.put("max.poll.records", config.kafkaMaxPollRecords());
        consumer.put("session.timeout.ms", config.kafkaSessionTimeoutMs());
        consumer.put("heartbeat.interval.ms", config.kafkaHeartbeatIntervalMs());
        consumer.put("max.poll.interval.ms", config.kafkaMaxPollIntervalMs());
        consumer.put("enable.auto.commit", false);
        consumer.put("auto.offset.reset", config.kafkaAutoOffsetReset());
        return consumer;
    }

    private ObjectNode buildInputFormat(Config config) {
        var inputFormat = mapper.createObjectNode();
        inputFormat.put("type", "protobuf");
        var decoder = inputFormat.putObject("protoBytesDecoder");
        decoder.put("type", "file");
        decoder.put("descriptor", config.protoDescriptorPath());
        decoder.put("protoMessageType", config.protoMessageType());
        return inputFormat;
    }

    private void addIoConfigSettings(ObjectNode io, Config config) {
        io.put("useEarliestOffset", config.useEarliestOffset());
        io.put("useTransaction", config.useTransaction());
        io.put("taskCount", config.taskCount());
        io.put("replicas", config.replicas());
        io.put("taskDuration", config.taskDuration());
        io.put("startDelay", config.startDelay());
        io.put("period", config.period());
        io.put("completionTimeout", config.completionTimeout());
        io.put("lateMessageRejectionPeriod", config.lateMessageRejectionPeriod());
        io.put("pollTimeout", config.pollTimeout());
        io.put("minimumMessageTime", config.minimumMessageTime());
    }

    private ObjectNode buildTuningConfig(Config config) {
        var tuning = mapper.createObjectNode();
        tuning.put("type", "kafka");
        addTuningBasicSettings(tuning, config);
        tuning.set("partitionsSpec", buildPartitionsSpec(config));
        tuning.set("splitHintSpec", buildSplitHintSpec(config));
        var indexSpec = buildIndexSpec(config.schema().indexSpec());
        tuning.set("indexSpec", indexSpec);
        tuning.set("indexSpecForIntermediatePersists", indexSpec);
        return tuning;
    }

    private void addTuningBasicSettings(ObjectNode tuning, Config config) {
        tuning.put("maxRowsInMemory", config.maxRowsInMemory());
        tuning.put("maxBytesInMemory", config.maxBytesInMemory());
        tuning.put("maxRowsPerSegment", config.maxRowsPerSegment());
        tuning.putNull("maxTotalRows");
        tuning.put("intermediatePersistPeriod", "PT10M");
        tuning.put("maxPendingPersists", config.maxPendingPersists());
        tuning.put("reportParseExceptions", config.reportParseExceptions());
        tuning.put("handoffConditionTimeout", config.handoffConditionTimeout());
        tuning.put("resetOffsetAutomatically", config.resetOffsetAutomatically());
        tuning.putNull("workerThreads");
        tuning.putNull("chatThreads");
        tuning.put("chatRetries", config.chatRetries());
        tuning.put("httpTimeout", config.httpTimeout());
        tuning.put("shutdownTimeout", config.shutdownTimeout());
        tuning.put("offsetFetchPeriod", config.offsetFetchPeriod());
        tuning.put("intermediateHandoffPeriod", config.intermediateHandoffPeriod());
        tuning.put("logParseExceptions", config.logParseExceptions());
        tuning.put("maxParseExceptions", config.maxParseExceptions());
        tuning.put("maxSavedParseExceptions", config.maxSavedParseExceptions());
        tuning.put("skipSequenceNumberAvailabilityCheck", config.skipSequenceNumberAvailabilityCheck());
    }

    private ObjectNode buildPartitionsSpec(Config config) {
        var partitionsSpec = mapper.createObjectNode();
        partitionsSpec.put("type", config.partitionsSpecType());
        var dims = partitionsSpec.putArray("partitionDimensions");
        config.secondaryPartitionDimensions().forEach(dims::add);
        partitionsSpec.put("targetRowsPerSegment", config.targetRowsPerSegment());
        return partitionsSpec;
    }

    private ObjectNode buildSplitHintSpec(Config config) {
        var splitHint = mapper.createObjectNode();
        splitHint.put("type", "maxSize");
        splitHint.put("maxSplitSize", config.maxSplitSize());
        splitHint.put("maxInputSegmentBytesPerTask", config.maxInputSegmentBytesPerTask());
        return splitHint;
    }

    private ObjectNode buildDataSchema(Config config) {
        var dataSchema = mapper.createObjectNode();
        dataSchema.put("dataSource", config.datasource());
        dataSchema.set("timestampSpec", buildTimestampSpec(config));
        dataSchema.set("dimensionsSpec", buildDimensionsSpec(config));
        dataSchema.set("metricsSpec", buildMetricsSpec(config));
        dataSchema.set("transformSpec", buildTransformSpec(config));
        dataSchema.set("granularitySpec", buildGranularitySpec(config));
        return dataSchema;
    }

    private ObjectNode buildTimestampSpec(Config config) {
        var timestampSpec = mapper.createObjectNode();
        timestampSpec.put("column", config.timestampColumn());
        timestampSpec.put("format", config.timestampFormat());
        timestampSpec.putNull("missingValue");
        return timestampSpec;
    }

    private ObjectNode buildDimensionsSpec(Config config) {
        var dimensionsSpec = mapper.createObjectNode();
        var dims = dimensionsSpec.putArray("dimensions");
        config.schema().dimensions().forEach(d -> {
            var dim = mapper.createObjectNode();
            dim.put("type", d.type());
            dim.put("name", d.name());
            dims.add(dim);
        });
        var exclusions = dimensionsSpec.putArray("dimensionExclusions");
        exclusions.add("settlement_ts").add("settlement_entry_ts").add("acceptance_ts").add("payee_access_manager_id");
        dimensionsSpec.put("includeAllDimensions", false);
        dimensionsSpec.put("useSchemaDiscovery", false);
        return dimensionsSpec;
    }

    private com.fasterxml.jackson.databind.node.ArrayNode buildMetricsSpec(Config config) {
        var metricsSpec = mapper.createArrayNode();
        config.schema().metrics().forEach(m -> {
            var metric = mapper.createObjectNode();
            metric.put("type", m.type());
            metric.put("name", m.name());
            if (m.fieldName() != null) {
                metric.put("fieldName", m.fieldName());
            }
            metricsSpec.add(metric);
        });
        return metricsSpec;
    }

    private ObjectNode buildTransformSpec(Config config) {
        var transformSpec = mapper.createObjectNode();
        var transforms = transformSpec.putArray("transforms");
        config.schema().transforms().forEach(t -> {
            var transform = mapper.createObjectNode();
            transform.put("type", "expression");
            transform.put("name", t.name());
            transform.put("expression", t.expression());
            transforms.add(transform);
        });
        transformSpec.putNull("filter");
        return transformSpec;
    }

    private ObjectNode buildGranularitySpec(Config config) {
        var granularitySpec = mapper.createObjectNode();
        granularitySpec.put("type", "uniform");
        granularitySpec.put("segmentGranularity", config.segmentGranularity());
        granularitySpec.put("queryGranularity", config.queryGranularity());
        granularitySpec.put("rollup", config.rollup());
        granularitySpec.putNull("intervals");
        return granularitySpec;
    }

    private ObjectNode buildIndexSpec(IndexSpec indexSpec) {
        var spec = mapper.createObjectNode();
        var bitmap = spec.putObject("bitmap");
        bitmap.put("type", indexSpec.bitmapType());
        spec.put("dimensionCompression", indexSpec.dimensionCompression());
        spec.put("metricCompression", indexSpec.metricCompression());
        spec.put("longEncoding", indexSpec.longEncoding());
        return spec;
    }
}
