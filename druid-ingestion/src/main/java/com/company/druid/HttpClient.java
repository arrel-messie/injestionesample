package com.company.druid;

import com.company.druid.exceptions.DruidException;
import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.time.Duration;
import java.util.concurrent.TimeUnit;

/**
 * HTTP client with retry logic and proper error handling
 */
public class HttpClient {
    private static final Logger log = LoggerFactory.getLogger(HttpClient.class);
    private final OkHttpClient client;
    private final ObjectMapper mapper;

    public HttpClient(int connectTimeoutSeconds, int readTimeoutSeconds, int writeTimeoutSeconds) {
        this.client = new OkHttpClient.Builder()
            .connectTimeout(connectTimeoutSeconds, TimeUnit.SECONDS)
            .readTimeout(readTimeoutSeconds, TimeUnit.SECONDS)
            .writeTimeout(writeTimeoutSeconds, TimeUnit.SECONDS)
            .build();
        this.mapper = new ObjectMapper();
    }

    public HttpClient() {
        this(10, 30, 30); // Default timeouts
    }

    /**
     * Execute HTTP request with retry logic
     */
    public String execute(Request request, int maxRetries) throws DruidException {
        IOException lastException = null;
        
        for (int attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                try (var response = client.newCall(request).execute()) {
                    if (response.isSuccessful()) {
                        return response.body().string();
                    } else {
                        var errorBody = response.body() != null ? response.body().string() : "No error body";
                        throw new DruidException(
                            String.format("HTTP %d: %s", response.code(), errorBody)
                        );
                    }
                }
            } catch (IOException e) {
                lastException = e;
                if (attempt < maxRetries) {
                    var delay = (long) Math.pow(2, attempt) * 1000; // Exponential backoff
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
        }
        
        throw new DruidException("Request failed after " + (maxRetries + 1) + " attempts", lastException);
    }

    public ObjectMapper mapper() {
        return mapper;
    }
}

