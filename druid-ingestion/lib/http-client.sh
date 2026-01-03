#!/usr/bin/env bash
#
# HTTP Client module - HTTP requests with retry logic
#

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Execute HTTP request with retry logic
http_request() {
    local method="${1:-GET}"
    local url="${2:-}"
    local data_file="${3:-}"
    local max_retries="${4:-3}"
    local retry_delay="${5:-2}"
    
    if [ -z "$url" ]; then
        log_error "URL is required"
        return 1
    fi
    
    local attempt=0
    local http_code
    local response
    
    while [ $attempt -lt $max_retries ]; do
        log_debug "HTTP ${method} attempt $((attempt + 1))/${max_retries}: $url"
        
        if [ -n "$data_file" ] && [ -f "$data_file" ]; then
            # POST with data
            response=$(curl -s -w "\n%{http_code}" \
                -X "$method" \
                -H "Content-Type: application/json" \
                -d @"$data_file" \
                "$url" 2>&1) || {
                log_warn "Network error on attempt $((attempt + 1))"
                attempt=$((attempt + 1))
                if [ $attempt -lt $max_retries ]; then
                    sleep $((retry_delay * attempt))
                fi
                continue
            }
        else
            # GET request
            response=$(curl -s -w "\n%{http_code}" \
                -X "$method" \
                -H "Accept: application/json" \
                "$url" 2>&1) || {
                log_warn "Network error on attempt $((attempt + 1))"
                attempt=$((attempt + 1))
                if [ $attempt -lt $max_retries ]; then
                    sleep $((retry_delay * attempt))
                fi
                continue
            }
        fi
        
        http_code=$(echo "$response" | tail -n1)
        response_body=$(echo "$response" | sed '$d')
        
        # Success (2xx)
        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
            echo "$response_body"
            return 0
        fi
        
        # Client error (4xx) - don't retry
        if [ "$http_code" -ge 400 ] && [ "$http_code" -lt 500 ]; then
            log_error "HTTP $http_code error: $response_body"
            return 1
        fi
        
        # Server error (5xx) - retry
        log_warn "HTTP $http_code error, retrying..."
        attempt=$((attempt + 1))
        if [ $attempt -lt $max_retries ]; then
            sleep $((retry_delay * attempt))
        fi
    done
    
    log_error "HTTP request failed after $max_retries attempts"
    return 1
}

# Pretty print JSON
pretty_json() {
    local json="${1:-}"
    
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq '.' 2>/dev/null || echo "$json"
    else
        echo "$json"
    fi
}

