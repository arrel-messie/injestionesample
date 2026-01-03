package com.company.druid.exceptions;

/**
 * Exception thrown when input validation fails
 */
public class ValidationException extends DruidException {
    public ValidationException(String message) {
        super(message);
    }
}

