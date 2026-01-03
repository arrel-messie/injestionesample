package com.company.druid.schema.record;

import java.util.List;

/**
 * Schema definition for Druid dimensions, metrics, transforms, and index specifications
 */
public record Schema(
    List<Dimension> dimensions,
    List<Metric> metrics,
    List<Transform> transforms,
    IndexSpec indexSpec
) {
    /**
     * Minimal default schema for testing only
     */
    public static Schema defaults() {
        return new Schema(
            List.of(),
            List.of(new Metric("count", "count", null)),
            List.of(),
            IndexSpec.defaults()
        );
    }
}
