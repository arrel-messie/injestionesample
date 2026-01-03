package com.company.druid;

import com.typesafe.config.Config;

import java.util.List;
import java.util.function.Function;

/**
 * Builder pattern for Config construction - reduces repetitive get() calls
 * Uses functional approach to map from Typesafe Config to our Config record
 */
public class ConfigBuilder {
    private final Config typesafeConfig;
    private final com.company.druid.Config defaults;

    public ConfigBuilder(Config typesafeConfig) {
        this.typesafeConfig = typesafeConfig;
        this.defaults = com.company.druid.Config.defaults();
    }

    // Functional getters - reduces code duplication
    public String str(String key, Function<com.company.druid.Config, String> getter) {
        return typesafeConfig.hasPath(key) ? typesafeConfig.getString(key) : getter.apply(defaults);
    }

    public int num(String key, Function<com.company.druid.Config, Integer> getter) {
        return typesafeConfig.hasPath(key) ? typesafeConfig.getInt(key) : getter.apply(defaults);
    }

    public long lng(String key, Function<com.company.druid.Config, Long> getter) {
        return typesafeConfig.hasPath(key) ? typesafeConfig.getLong(key) : getter.apply(defaults);
    }

    public boolean bool(String key, Function<com.company.druid.Config, Boolean> getter) {
        return typesafeConfig.hasPath(key) ? typesafeConfig.getBoolean(key) : getter.apply(defaults);
    }

    public List<String> list(String key, Function<com.company.druid.Config, List<String>> getter) {
        if (!typesafeConfig.hasPath(key)) return getter.apply(defaults);
        try {
            return typesafeConfig.getStringList(key);
        } catch (Exception e) {
            // Try parsing as JSON string
            try {
                var mapper = new com.fasterxml.jackson.databind.ObjectMapper();
                var array = mapper.readTree(typesafeConfig.getString(key));
                var list = new java.util.ArrayList<String>();
                for (var item : array) list.add(item.asText());
                return list;
            } catch (Exception ex) {
                return getter.apply(defaults);
            }
        }
    }
}
