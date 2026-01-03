package com.company.druid.client;

import com.company.druid.exceptions.DruidException;
import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

/**
 * HTTP client with retry logic and proper error handling
 */
public class HttpClient {
    private static final Logger log = LoggerFactory.getLogger(HttpClient.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private final OkHttpClient client;

    public HttpClient(int connectTimeoutSeconds, int readTimeoutSeconds, int writeTimeoutSeconds) {
        this.client = new OkHttpClient.Builder()
            .connectTimeout(connectTimeoutSeconds, TimeUnit.SECONDS)
            .readTimeout(readTimeoutSeconds, TimeUnit.SECONDS)
            .writeTimeout(writeTimeoutSeconds, TimeUnit.SECONDS)
            .build();
    }

    public HttpClient() {
        this(10, 30, 30);
    }

    /**
     * Execute HTTP request with retry logic
     * Retries only on network errors (IOException), not on HTTP errors (4xx/5xx)
     */
    public String execute(Request request, int maxRetries) throws DruidException {
        IOException lastException = null;
        
        for (int attempt = 0; attempt <= maxRetries; attempt++) {
            try (var response = client.newCall(request).execute()) {
                if (response.isSuccessful()) {
                    return readBody(response);
                }
                // HTTP errors (4xx/5xx) should not be retried
                throw new DruidException("HTTP %d: %s".formatted(response.code(), readBody(response)));
            } catch (IOException e) {
                lastException = e;
                if (attempt < maxRetries) {
                    sleepWithBackoff(attempt, maxRetries, e);
                }
            }
        }
        
        throw new DruidException("Request failed after %d attempts".formatted(maxRetries + 1), lastException);
    }

    /**
     * Execute request and return pretty-printed JSON
     */
    public String executeAndPrettyPrint(Request request, int maxRetries) throws DruidException {
        var json = execute(request, maxRetries);
        try {
            return MAPPER.writerWithDefaultPrettyPrinter()
                .writeValueAsString(MAPPER.readValue(json, Object.class));
        } catch (Exception e) {
            log.debug("Failed to pretty-print JSON, returning raw: {}", e.getMessage());
            return json;
        }
    }

    public static ObjectMapper mapper() {
        return MAPPER;
    }

    private String readBody(Response response) throws IOException {
        return response.body() != null ? response.body().string() : "";
    }

    private void sleepWithBackoff(int attempt, int maxRetries, IOException e) throws DruidException {
        var delay = (1L << attempt) * 1000; // Bit shift: 2^attempt * 1000ms
        log.warn("Request failed (attempt {}/{}), retrying in {}ms: {}", 
            attempt + 1, maxRetries + 1, delay, e.getMessage());
        try {
            Thread.sleep(delay);
        } catch (InterruptedException ie) {
            Thread.currentThread().interrupt();
            throw new DruidException("Request interrupted", ie);
        }
    }
}
