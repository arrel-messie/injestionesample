package com.company.druid.exceptions;

/**
 * Exception thrown when configuration is invalid or missing
 */
public class ConfigException extends DruidException {
    public ConfigException(String message) {
        super(message);
    }
    public ConfigException(String message, Throwable cause) {
        super(message, cause);
    }
}

