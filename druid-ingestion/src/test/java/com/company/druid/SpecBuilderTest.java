package com.company.druid;

import com.company.druid.config.Config;
import com.company.druid.spec.SpecBuilder;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class SpecBuilderTest {

    @Test
    void testBuild_createsValidSpec() {
        var config = Config.defaults();
        var builder = new SpecBuilder();
        
        var spec = builder.build(config, "dev");
        
        assertNotNull(spec);
        assertEquals("kafka", spec.get("type").asText());
        assertTrue(spec.has("spec"));
        
        var specContent = (ObjectNode) spec.get("spec");
        assertTrue(specContent.has("ioConfig"));
        assertTrue(specContent.has("tuningConfig"));
        assertTrue(specContent.has("dataSchema"));
    }

    @Test
    void testBuild_containsKafkaConfig() {
        var config = Config.defaults();
        var builder = new SpecBuilder();
        
        var spec = builder.build(config, "test");
        var ioConfig = (ObjectNode) spec.get("spec").get("ioConfig");
        
        assertEquals("kafka", ioConfig.get("type").asText());
        assertTrue(ioConfig.has("topic"));
        assertTrue(ioConfig.has("consumerProperties"));
    }

    @Test
    void testBuild_containsDataSchema() {
        var config = Config.defaults();
        var builder = new SpecBuilder();
        
        var spec = builder.build(config, "dev");
        var dataSchema = (ObjectNode) spec.get("spec").get("dataSchema");
        
        assertEquals(config.druid().datasource(), dataSchema.get("dataSource").asText());
        assertTrue(dataSchema.has("timestampSpec"));
        assertTrue(dataSchema.has("dimensionsSpec"));
        assertTrue(dataSchema.has("metricsSpec"));
    }
}

