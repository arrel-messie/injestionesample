package com.company.druid.exceptions;

/**
 * Base exception for Druid-related errors
 */
public class DruidException extends Exception {
    public DruidException(String message) {
        super(message);
    }

    public DruidException(String message, Throwable cause) {
        super(message, cause);
    }
}

