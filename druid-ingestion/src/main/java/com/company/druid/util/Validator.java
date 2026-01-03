package com.company.druid.util;

import com.company.druid.exceptions.ValidationException;

import java.util.Set;

/**
 * Input validation utilities
 */
public class Validator {
    private static final Set<String> VALID_ENVIRONMENTS = Set.of("dev", "staging", "prod", "test");

    /**
     * Validate environment name
     */
    public static void validateEnvironment(String env) throws ValidationException {
        if (env == null || env.isBlank()) {
            throw new ValidationException("Environment (-e) is required");
        }
        if (!VALID_ENVIRONMENTS.contains(env.toLowerCase())) {
            throw new ValidationException(
                String.format("Invalid environment '%s'. Must be one of: %s", 
                    env, String.join(", ", VALID_ENVIRONMENTS))
            );
        }
    }

    /**
     * Validate URL format
     */
    public static void validateUrl(String url, String name) throws ValidationException {
        if (url == null || url.isBlank()) {
            throw new ValidationException(name + " URL is required");
        }
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            throw new ValidationException(
                String.format("Invalid %s URL: %s (must start with http:// or https://)", name, url)
            );
        }
    }
}

