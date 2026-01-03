package com.company.druid;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

/**
 * Loads Schema from YAML files or provides defaults
 * Extracted from Schema class to reduce complexity
 */
public class SchemaLoader {
    private static final Logger log = LoggerFactory.getLogger(SchemaLoader.class);
    private static final ObjectMapper YAML_MAPPER = new ObjectMapper(new YAMLFactory());

    /**
     * Load schema from datasource-specific or environment-specific file
     * Priority: schema-{datasource}-{env}.yml > schema-{datasource}.yml > schema-{env}.yml > schema.yml
     */
    public static Schema load(Path moduleRoot, String env, String datasourceName) {
        Path schemaFile = null;
        
        // Try datasource-specific files first
        if (datasourceName != null) {
            var dsEnvFile = moduleRoot.resolve("config/schema-" + datasourceName + "-" + env + ".yml");
            var dsFile = moduleRoot.resolve("config/schema-" + datasourceName + ".yml");
            
            if (Files.exists(dsEnvFile)) {
                schemaFile = dsEnvFile;
                log.debug("Loading datasource-specific schema: {}", dsEnvFile);
            } else if (Files.exists(dsFile)) {
                schemaFile = dsFile;
                log.debug("Loading datasource schema: {}", dsFile);
            }
        }
        
        // Fallback to environment-specific or default
        if (schemaFile == null) {
            var envSchemaFile = moduleRoot.resolve("config/schema-" + env + ".yml");
            var defaultSchemaFile = moduleRoot.resolve("config/schema.yml");
            
            if (Files.exists(envSchemaFile)) {
                schemaFile = envSchemaFile;
                log.debug("Loading environment-specific schema: {}", envSchemaFile);
            } else if (Files.exists(defaultSchemaFile)) {
                schemaFile = defaultSchemaFile;
                log.debug("Loading default schema: {}", defaultSchemaFile);
            }
        }
        
        if (schemaFile == null) {
            log.warn("No schema file found, using defaults");
            return defaults();
        }

        try {
            var root = YAML_MAPPER.readTree(schemaFile.toFile());
            var dimensions = parseDimensions(root);
            var metrics = parseMetrics(root);
            var transforms = parseTransforms(root);
            var indexSpec = parseIndexSpec(root);

            return new Schema(
                dimensions.isEmpty() ? defaults().dimensions() : dimensions,
                metrics.isEmpty() ? defaults().metrics() : metrics,
                transforms.isEmpty() ? defaults().transforms() : transforms,
                indexSpec
            );
        } catch (Exception e) {
            log.warn("Failed to load {}, using defaults: {}", schemaFile, e.getMessage());
            return defaults();
        }
    }
    
    /**
     * Backward compatibility: load without datasource name
     */
    public static Schema load(Path moduleRoot, String env) {
        return load(moduleRoot, env, null);
    }

    /**
     * Default schema configuration
     */
    public static Schema defaults() {
        return new Schema(
            List.of(
                new Dimension("string", "uetr"),
                new Dimension("string", "rtgs_business_date"),
                new Dimension("string", "tx_type"),
                new Dimension("string", "status"),
                new Dimension("string", "currency"),
                new Dimension("string", "payer_access_manager_bic"),
                new Dimension("string", "payer_access_manager_id"),
                new Dimension("string", "payee_access_manager_bic"),
                new Dimension("string", "reason_code"),
                new Dimension("string", "payment_type_code")
            ),
            List.of(
                new Metric("count", "count", null),
                new Metric("doubleSum", "amount_sum", "amount")
            ),
            List.of(
                new Transform("tx_type", "upper(txType)"),
                new Transform("status", "upper(status)"),
                new Transform("currency", "upper(currency)"),
                new Transform("payer_access_manager_bic", "upper(payerAccessManagerBic)"),
                new Transform("payee_access_manager_bic", "upper(payeeAccessManagerBic)"),
                new Transform("reason_code", "upper(reasonCode)"),
                new Transform("payment_type_code", "upper(paymentTypeCode)")
            ),
            new IndexSpec("roaring", "lz4", "lz4", "longs")
        );
    }

    private static List<Dimension> parseDimensions(com.fasterxml.jackson.databind.JsonNode root) {
        var dimensions = new ArrayList<Dimension>();
        if (root.has("dimensions")) {
            for (var dim : root.get("dimensions")) {
                dimensions.add(new Dimension(
                    dim.get("type").asText(),
                    dim.get("name").asText()
                ));
            }
        }
        return dimensions;
    }

    private static List<Metric> parseMetrics(com.fasterxml.jackson.databind.JsonNode root) {
        var metrics = new ArrayList<Metric>();
        if (root.has("metrics")) {
            for (var m : root.get("metrics")) {
                metrics.add(new Metric(
                    m.get("type").asText(),
                    m.get("name").asText(),
                    m.has("fieldName") ? m.get("fieldName").asText() : null
                ));
            }
        }
        return metrics;
    }

    private static List<Transform> parseTransforms(com.fasterxml.jackson.databind.JsonNode root) {
        var transforms = new ArrayList<Transform>();
        if (root.has("transforms")) {
            for (var t : root.get("transforms")) {
                transforms.add(new Transform(
                    t.get("name").asText(),
                    t.get("expression").asText()
                ));
            }
        }
        return transforms;
    }

    private static IndexSpec parseIndexSpec(com.fasterxml.jackson.databind.JsonNode root) {
        if (root.has("indexSpec")) {
            var idx = root.get("indexSpec");
            return new IndexSpec(
                idx.get("bitmap").get("type").asText(),
                idx.get("dimensionCompression").asText(),
                idx.get("metricCompression").asText(),
                idx.get("longEncoding").asText()
            );
        }
        return IndexSpec.defaults();
    }
}
