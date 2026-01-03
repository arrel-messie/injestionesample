package com.company.druid.schema;

import com.company.druid.exceptions.ConfigException;
import com.company.druid.schema.record.Schema;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Loads Schema from YAML files using Jackson's direct mapping
 */
public class SchemaLoader {
    private static final Logger log = LoggerFactory.getLogger(SchemaLoader.class);
    private static final ObjectMapper YAML_MAPPER = new ObjectMapper(new YAMLFactory());

    /**
     * Load schema from schema.yml, throws ConfigException if not found or invalid
     */
    public static Schema load(Path moduleRoot) throws ConfigException {
        var schemaFile = moduleRoot.resolve("config/schema.yml");
        
        if (!Files.exists(schemaFile)) {
            throw new ConfigException("schema.yml not found at " + schemaFile);
        }
        
        try {
            return YAML_MAPPER.readValue(schemaFile.toFile(), Schema.class);
        } catch (Exception e) {
            throw new ConfigException("Failed to load schema.yml from " + schemaFile + ": " + e.getMessage(), e);
        }
    }
}
