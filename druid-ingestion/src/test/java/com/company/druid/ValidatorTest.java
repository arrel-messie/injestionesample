package com.company.druid;

import com.company.druid.exceptions.ValidationException;
import com.company.druid.util.Validator;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class ValidatorTest {

    @Test
    void testValidateEnvironment_valid() throws ValidationException {
        assertDoesNotThrow(() -> Validator.validateEnvironment("dev"));
        assertDoesNotThrow(() -> Validator.validateEnvironment("staging"));
        assertDoesNotThrow(() -> Validator.validateEnvironment("prod"));
    }

    @Test
    void testValidateEnvironment_invalid() {
        assertThrows(ValidationException.class, () -> Validator.validateEnvironment(null));
        assertThrows(ValidationException.class, () -> Validator.validateEnvironment(""));
        assertThrows(ValidationException.class, () -> Validator.validateEnvironment("invalid"));
    }

    @Test
    void testValidateUrl_valid() throws ValidationException {
        assertDoesNotThrow(() -> Validator.validateUrl("http://localhost:8080", "Test"));
        assertDoesNotThrow(() -> Validator.validateUrl("https://example.com", "Test"));
    }

    @Test
    void testValidateUrl_invalid() {
        assertThrows(ValidationException.class, () -> Validator.validateUrl(null, "Test"));
        assertThrows(ValidationException.class, () -> Validator.validateUrl("", "Test"));
        assertThrows(ValidationException.class, () -> Validator.validateUrl("ftp://example.com", "Test"));
    }
}

