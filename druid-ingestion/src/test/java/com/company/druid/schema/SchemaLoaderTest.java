package com.company.druid.schema;

import com.company.druid.exceptions.ConfigException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.*;

class SchemaLoaderTest {

    @Test
    void testLoad_validSchema(@TempDir Path tempDir) throws Exception {
        var configDir = tempDir.resolve("config");
        Files.createDirectories(configDir);
        
        var schemaYml = """
            dimensions:
              - type: string
                name: dimension1
            metrics:
              - type: count
                name: count
              - type: longSum
                name: total
                fieldName: amount
            transforms:
              - name: computed_field
                expression: "field1 + field2"
            indexSpec:
              bitmapType: roaring
              dimensionCompression: lz4
              metricCompression: lz4
              longEncoding: longs
            """;
        Files.writeString(configDir.resolve("schema.yml"), schemaYml);
        
        var schema = SchemaLoader.load(tempDir);
        
        assertNotNull(schema);
        assertEquals(1, schema.dimensions().size());
        assertEquals("dimension1", schema.dimensions().get(0).name());
        assertEquals(2, schema.metrics().size());
        assertEquals(1, schema.transforms().size());
        assertNotNull(schema.indexSpec());
        assertEquals("roaring", schema.indexSpec().bitmapType());
    }

    @Test
    void testLoad_missingSchemaFile(@TempDir Path tempDir) {
        assertThrows(ConfigException.class, () -> SchemaLoader.load(tempDir));
    }

    @Test
    void testLoad_invalidYaml(@TempDir Path tempDir) throws Exception {
        var configDir = tempDir.resolve("config");
        Files.createDirectories(configDir);
        
        Files.writeString(configDir.resolve("schema.yml"), "invalid: yaml: content: [");
        
        assertThrows(ConfigException.class, () -> SchemaLoader.load(tempDir));
    }

    @Test
    void testLoad_emptySchema(@TempDir Path tempDir) throws Exception {
        var configDir = tempDir.resolve("config");
        Files.createDirectories(configDir);
        
        var schemaYml = """
            dimensions: []
            metrics: []
            transforms: []
            indexSpec:
              bitmapType: roaring
              dimensionCompression: lz4
              metricCompression: lz4
              longEncoding: longs
            """;
        Files.writeString(configDir.resolve("schema.yml"), schemaYml);
        
        var schema = SchemaLoader.load(tempDir);
        
        assertNotNull(schema);
        assertTrue(schema.dimensions().isEmpty());
        assertTrue(schema.metrics().isEmpty());
        assertTrue(schema.transforms().isEmpty());
    }
}

