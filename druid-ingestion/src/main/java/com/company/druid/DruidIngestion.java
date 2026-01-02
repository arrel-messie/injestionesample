package com.company.druid;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import okhttp3.*;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;
import java.util.Properties;

public class DruidIngestion {

    private static final ObjectMapper mapper = new ObjectMapper();

    public static void main(String[] args) {
        if (args.length == 0) {
            printUsage();
            System.exit(1);
        }

        String command = args[0];
        try {
            switch (command) {
                case "build":
                    build(args);
                    break;
                case "deploy":
                    deploy(args);
                    break;
                case "status":
                    status(args);
                    break;
                default:
                    System.err.println("Unknown command: " + command);
                    printUsage();
                    System.exit(1);
            }
        } catch (Exception e) {
            System.err.println("ERROR: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }

    private static void printUsage() {
        System.out.println("Usage: java -jar druid-ingestion.jar <command> [options]");
        System.out.println("Commands:");
        System.out.println("  build -e <env> [-o <output>]  Build supervisor spec");
        System.out.println("  deploy -e <env>                 Deploy supervisor");
        System.out.println("  status -e <env>                Get supervisor status");
    }

    private static void build(String[] args) throws Exception {
        String env = getArg(args, "-e");
        String output = getArg(args, "-o");
        if (env == null) {
            throw new IllegalArgumentException("Environment (-e) required");
        }

        Path moduleRoot = getModuleRoot();
        Path outputFile = output != null ? Paths.get(output) 
            : moduleRoot.resolve("druid-specs/generated/supervisor-spec-" + env + ".json");

        // Load environment config
        Properties envProps = loadEnvFile(moduleRoot, env);
        
        // Load schema
        JsonNode schema = mapper.readTree(moduleRoot.resolve("config/schema.json").toFile());

        // Build spec directly
        ObjectNode spec = mapper.createObjectNode();
        spec.put("type", "kafka");
        
        ObjectNode specContent = spec.putObject("spec");
        specContent.set("ioConfig", buildIoConfig(envProps, env));
        specContent.set("tuningConfig", buildTuningConfig(envProps, schema));
        specContent.set("dataSchema", buildDataSchema(envProps, schema));

        Files.createDirectories(outputFile.getParent());
        mapper.writerWithDefaultPrettyPrinter().writeValue(outputFile.toFile(), spec);
        System.out.println(outputFile.toString());
    }

    private static ObjectNode buildIoConfig(Properties env, String envName) {
        ObjectNode io = mapper.createObjectNode();
        io.put("type", "kafka");
        
        ObjectNode consumer = io.putObject("consumerProperties");
        consumer.put("bootstrap.servers", env.getProperty("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"));
        consumer.put("security.protocol", env.getProperty("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT"));
        consumer.put("sasl.mechanism", env.getProperty("KAFKA_SASL_MECHANISM", "PLAIN"));
        consumer.put("sasl.jaas.config", env.getProperty("KAFKA_SASL_JAAS_CONFIG", ""));
        consumer.put("ssl.endpoint.identification.algorithm", env.getProperty("KAFKA_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM", ""));
        consumer.put("group.id", "druid-" + env.getProperty("DATASOURCE_NAME", "datasource") + "-" + envName);
        consumer.put("fetch.min.bytes", Integer.parseInt(env.getProperty("KAFKA_FETCH_MIN_BYTES", "1048576")));
        consumer.put("fetch.max.wait.ms", Integer.parseInt(env.getProperty("KAFKA_FETCH_MAX_WAIT_MS", "500")));
        consumer.put("max.poll.records", Integer.parseInt(env.getProperty("KAFKA_MAX_POLL_RECORDS", "500")));
        consumer.put("session.timeout.ms", Integer.parseInt(env.getProperty("KAFKA_SESSION_TIMEOUT_MS", "30000")));
        consumer.put("heartbeat.interval.ms", Integer.parseInt(env.getProperty("KAFKA_HEARTBEAT_INTERVAL_MS", "3000")));
        consumer.put("max.poll.interval.ms", Integer.parseInt(env.getProperty("KAFKA_MAX_POLL_INTERVAL_MS", "300000")));
        consumer.put("enable.auto.commit", false);
        consumer.put("auto.offset.reset", env.getProperty("KAFKA_AUTO_OFFSET_RESET", "latest"));

        io.put("topic", env.getProperty("KAFKA_TOPIC", "topic"));
        
        ObjectNode inputFormat = io.putObject("inputFormat");
        inputFormat.put("type", "protobuf");
        ObjectNode decoder = inputFormat.putObject("protoBytesDecoder");
        decoder.put("type", "file");
        decoder.put("descriptor", env.getProperty("PROTO_DESCRIPTOR_PATH", "file:///opt/shared/schemas/settlement_transaction.desc"));
        decoder.put("protoMessageType", env.getProperty("PROTO_MESSAGE_TYPE", "com.company.PaymentTransactionEvent"));

        io.put("useEarliestOffset", Boolean.parseBoolean(env.getProperty("USE_EARLIEST_OFFSET", "false")));
        io.put("useTransaction", Boolean.parseBoolean(env.getProperty("USE_TRANSACTION", "true")));
        io.put("taskCount", Integer.parseInt(env.getProperty("TASK_COUNT", "10")));
        io.put("replicas", Integer.parseInt(env.getProperty("REPLICAS", "2")));
        io.put("taskDuration", env.getProperty("TASK_DURATION", "PT1H"));
        io.put("startDelay", env.getProperty("START_DELAY", "PT5S"));
        io.put("period", env.getProperty("PERIOD", "PT30S"));
        io.put("completionTimeout", env.getProperty("COMPLETION_TIMEOUT", "PT1H"));
        io.put("lateMessageRejectionPeriod", env.getProperty("LATE_MESSAGE_REJECTION_PERIOD", "PT1H"));
        io.put("pollTimeout", Integer.parseInt(env.getProperty("POLL_TIMEOUT", "100")));
        io.put("minimumMessageTime", env.getProperty("MINIMUM_MESSAGE_TIME", "1970-01-01T00:00:00.000Z"));

        return io;
    }

    private static ObjectNode buildTuningConfig(Properties env, JsonNode schema) {
        ObjectNode tuning = mapper.createObjectNode();
        tuning.put("type", "kafka");
        tuning.put("maxRowsInMemory", Integer.parseInt(env.getProperty("MAX_ROWS_IN_MEMORY", "500000")));
        tuning.put("maxBytesInMemory", Long.parseLong(env.getProperty("MAX_BYTES_IN_MEMORY", "536870912")));
        tuning.put("maxRowsPerSegment", Integer.parseInt(env.getProperty("MAX_ROWS_PER_SEGMENT", "5000000")));
        tuning.put("maxTotalRows", (JsonNode) null);
        tuning.put("intermediatePersistPeriod", env.getProperty("INTERMEDIATE_PERSIST_PERIOD", "PT10M"));
        tuning.put("maxPendingPersists", Integer.parseInt(env.getProperty("MAX_PENDING_PERSISTS", "2")));
        tuning.put("reportParseExceptions", Boolean.parseBoolean(env.getProperty("REPORT_PARSE_EXCEPTIONS", "true")));
        tuning.put("handoffConditionTimeout", Long.parseLong(env.getProperty("HANDOFF_CONDITION_TIMEOUT", "900000")));
        tuning.put("resetOffsetAutomatically", Boolean.parseBoolean(env.getProperty("RESET_OFFSET_AUTOMATICALLY", "false")));
        tuning.put("workerThreads", (JsonNode) null);
        tuning.put("chatThreads", (JsonNode) null);
        tuning.put("chatRetries", Integer.parseInt(env.getProperty("CHAT_RETRIES", "8")));
        tuning.put("httpTimeout", env.getProperty("HTTP_TIMEOUT", "PT10S"));
        tuning.put("shutdownTimeout", env.getProperty("SHUTDOWN_TIMEOUT", "PT80S"));
        tuning.put("offsetFetchPeriod", env.getProperty("OFFSET_FETCH_PERIOD", "PT30S"));
        tuning.put("intermediateHandoffPeriod", env.getProperty("INTERMEDIATE_HANDOFF_PERIOD", "P2147483647D"));
        tuning.put("logParseExceptions", Boolean.parseBoolean(env.getProperty("LOG_PARSE_EXCEPTIONS", "true")));
        tuning.put("maxParseExceptions", Integer.parseInt(env.getProperty("MAX_PARSE_EXCEPTIONS", "10000")));
        tuning.put("maxSavedParseExceptions", Integer.parseInt(env.getProperty("MAX_SAVED_PARSE_EXCEPTIONS", "100")));
        tuning.put("skipSequenceNumberAvailabilityCheck", Boolean.parseBoolean(env.getProperty("SKIP_SEQUENCE_NUMBER_AVAILABILITY_CHECK", "false")));

        ObjectNode partitionsSpec = tuning.putObject("partitionsSpec");
        partitionsSpec.put("type", env.getProperty("PARTITIONS_SPEC_TYPE", "dynamic"));
        if (env.containsKey("SECONDARY_PARTITION_DIMENSIONS")) {
            try {
                partitionsSpec.set("partitionDimensions", mapper.readTree(env.getProperty("SECONDARY_PARTITION_DIMENSIONS")));
            } catch (Exception e) {
                partitionsSpec.putArray("partitionDimensions");
            }
        } else {
            partitionsSpec.putArray("partitionDimensions");
        }
        partitionsSpec.put("targetRowsPerSegment", Integer.parseInt(env.getProperty("TARGET_ROWS_PER_SEGMENT", "5000000")));

        ObjectNode splitHint = tuning.putObject("splitHintSpec");
        splitHint.put("type", "maxSize");
        splitHint.put("maxSplitSize", Long.parseLong(env.getProperty("MAX_SPLIT_SIZE", "1073741824")));
        splitHint.put("maxInputSegmentBytesPerTask", Long.parseLong(env.getProperty("MAX_INPUT_SEGMENT_BYTES_PER_TASK", "10737418240")));

        if (schema.has("indexSpec")) {
            tuning.set("indexSpec", schema.get("indexSpec"));
            tuning.set("indexSpecForIntermediatePersists", schema.get("indexSpec"));
        }

        return tuning;
    }

    private static ObjectNode buildDataSchema(Properties env, JsonNode schema) {
        ObjectNode dataSchema = mapper.createObjectNode();
        dataSchema.put("dataSource", env.getProperty("DATASOURCE_NAME", "datasource"));

        ObjectNode timestampSpec = dataSchema.putObject("timestampSpec");
        timestampSpec.put("column", env.getProperty("TIMESTAMP_COLUMN", "settlementTimestampMs"));
        timestampSpec.put("format", env.getProperty("TIMESTAMP_FORMAT", "millis"));
        timestampSpec.put("missingValue", (JsonNode) null);

        ObjectNode dimensionsSpec = dataSchema.putObject("dimensionsSpec");
        if (schema.has("dimensions")) {
            dimensionsSpec.set("dimensions", schema.get("dimensions"));
        } else {
            dimensionsSpec.putArray("dimensions");
        }
        dimensionsSpec.putArray("dimensionExclusions").add("settlement_ts").add("settlement_entry_ts").add("acceptance_ts").add("payee_access_manager_id");
        dimensionsSpec.put("includeAllDimensions", false);
        dimensionsSpec.put("useSchemaDiscovery", false);

        if (schema.has("metrics")) {
            dataSchema.set("metricsSpec", schema.get("metrics"));
        } else {
            dataSchema.putArray("metricsSpec");
        }

        ObjectNode transformSpec = dataSchema.putObject("transformSpec");
        if (schema.has("transforms")) {
            transformSpec.set("transforms", schema.get("transforms"));
        } else {
            transformSpec.putArray("transforms");
        }
        transformSpec.put("filter", (JsonNode) null);

        ObjectNode granularitySpec = dataSchema.putObject("granularitySpec");
        granularitySpec.put("type", "uniform");
        granularitySpec.put("segmentGranularity", env.getProperty("SEGMENT_GRANULARITY", "DAY"));
        granularitySpec.put("queryGranularity", env.getProperty("QUERY_GRANULARITY", "NONE"));
        granularitySpec.put("rollup", Boolean.parseBoolean(env.getProperty("ROLLUP", "false")));
        granularitySpec.put("intervals", (JsonNode) null);

        return dataSchema;
    }

    private static void deploy(String[] args) throws Exception {
        String env = getArg(args, "-e");
        if (env == null) {
            throw new IllegalArgumentException("Environment (-e) required");
        }

        Path moduleRoot = getModuleRoot();
        Path specFile = moduleRoot.resolve("druid-specs/generated/supervisor-spec-" + env + ".json");
        
        if (!specFile.toFile().exists()) {
            build(new String[]{"build", "-e", env, "-o", specFile.toString()});
        }

        String druidUrl = loadEnvVar(moduleRoot, env, "DRUID_OVERLORD_URL");
        String specJson = Files.readString(specFile);

        OkHttpClient httpClient = new OkHttpClient();
        RequestBody body = RequestBody.create(specJson, MediaType.get("application/json"));
        Request request = new Request.Builder()
            .url(druidUrl + "/druid/indexer/v1/supervisor")
            .post(body)
            .build();

        try (Response response = httpClient.newCall(request).execute()) {
            if (response.isSuccessful()) {
                System.out.println("Deployment successful (HTTP " + response.code() + ")");
                System.out.println(response.body().string());
            } else {
                System.err.println("ERROR: Deployment failed (HTTP " + response.code() + ")");
                System.err.println(response.body().string());
                System.exit(1);
            }
        }
    }

    private static void status(String[] args) throws Exception {
        String env = getArg(args, "-e");
        if (env == null) {
            throw new IllegalArgumentException("Environment (-e) required");
        }

        Path moduleRoot = getModuleRoot();
        String druidUrl = loadEnvVar(moduleRoot, env, "DRUID_OVERLORD_URL");
        String datasource = loadEnvVar(moduleRoot, env, "DATASOURCE_NAME");

        OkHttpClient httpClient = new OkHttpClient();
        Request request = new Request.Builder()
            .url(druidUrl + "/druid/indexer/v1/supervisor/" + datasource + "/status")
            .get()
            .build();

        try (Response response = httpClient.newCall(request).execute()) {
            if (response.isSuccessful()) {
                String json = response.body().string();
                Object jsonObj = mapper.readValue(json, Object.class);
                System.out.println(mapper.writerWithDefaultPrettyPrinter().writeValueAsString(jsonObj));
            } else {
                System.err.println("ERROR: Failed to get status (HTTP " + response.code() + ")");
                System.exit(1);
            }
        }
    }

    private static String getArg(String[] args, String flag) {
        for (int i = 0; i < args.length - 1; i++) {
            if (flag.equals(args[i])) {
                return args[i + 1];
            }
        }
        return null;
    }

    private static Path getModuleRoot() {
        Path current = Paths.get("").toAbsolutePath();
        while (current != null && !current.resolve("config").toFile().exists()) {
            current = current.getParent();
        }
        return current != null ? current : Paths.get("").toAbsolutePath();
    }

    private static Properties loadEnvFile(Path moduleRoot, String env) throws Exception {
        Properties props = new Properties();
        Path envFile = moduleRoot.resolve("config/" + env + ".env");
        if (envFile.toFile().exists()) {
            String content = Files.readString(envFile);
            for (String line : content.split("\n")) {
                line = line.trim();
                if (line.isEmpty() || line.startsWith("#")) continue;
                int eq = line.indexOf('=');
                if (eq > 0) {
                    String key = line.substring(0, eq).trim();
                    String value = line.substring(eq + 1).trim();
                    if ((value.startsWith("\"") && value.endsWith("\"")) ||
                        (value.startsWith("'") && value.endsWith("'"))) {
                        value = value.substring(1, value.length() - 1);
                    }
                    props.setProperty(key, value);
                }
            }
        }
        
        // Also load from system environment
        for (Map.Entry<String, String> entry : System.getenv().entrySet()) {
            if (!props.containsKey(entry.getKey())) {
                props.setProperty(entry.getKey(), entry.getValue());
            }
        }
        
        return props;
    }

    private static String loadEnvVar(Path moduleRoot, String env, String varName) throws Exception {
        Properties props = loadEnvFile(moduleRoot, env);
        String value = props.getProperty(varName);
        if (value == null) {
            throw new Exception(varName + " not found in config/" + env + ".env");
        }
        return value;
    }
}
