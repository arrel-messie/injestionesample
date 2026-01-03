package com.company.druid;

import java.util.List;

/**
 * Schema definition for Druid dimensions, metrics, transforms, and index specifications
 * Simple immutable record - loading logic extracted to SchemaLoader
 */
public record Schema(
    List<Dimension> dimensions,
    List<Metric> metrics,
    List<Transform> transforms,
    IndexSpec indexSpec
) {
    /**
     * Default schema configuration
     */
    public static Schema defaults() {
        return SchemaLoader.defaults();
    }
}

/**
 * Dimension definition
 */
record Dimension(String type, String name) {}

/**
 * Metric definition
 */
record Metric(String type, String name, String fieldName) {}

/**
 * Transform definition
 */
record Transform(String name, String expression) {}

/**
 * Index specification
 */
record IndexSpec(String bitmapType, String dimensionCompression, String metricCompression, String longEncoding) {
    static IndexSpec defaults() {
        return new IndexSpec("roaring", "lz4", "lz4", "longs");
    }
}
