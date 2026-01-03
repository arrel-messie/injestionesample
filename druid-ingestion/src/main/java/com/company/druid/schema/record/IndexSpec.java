package com.company.druid.schema.record;

/**
 * Index specification for Druid segments
 */
public record IndexSpec(
    String bitmapType,
    String dimensionCompression,
    String metricCompression,
    String longEncoding
) {
    public static IndexSpec defaults() {
        return new IndexSpec("roaring", "lz4", "lz4", "longs");
    }
}
