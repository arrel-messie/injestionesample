#!/usr/bin/env bash
#
# YAML Helper - Centralized YAML parsing with fallback
#

# Get YAML value (supports dot notation like .key.subkey)
yaml_get() {
    local file="$1"
    local key="${2:-}"
    local default="${3:-}"
    
    if command -v yq >/dev/null 2>&1; then
        yq eval "$key" "$file" 2>/dev/null || echo "$default"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import yaml, sys
try:
    with open('$file') as f:
        data = yaml.safe_load(f)
        keys = '$key'.lstrip('.').split('.')
        result = data
        for k in keys:
            result = result.get(k, {}) if isinstance(result, dict) else None
            if result is None:
                break
        print(result if isinstance(result, (str, int, bool)) and result != {} else '')
except:
    pass
" 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

# Convert YAML to JSON
yaml_to_json() {
    local file="$1"
    if command -v yq >/dev/null 2>&1; then
        yq eval -o=json "$file" 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import yaml, json; print(json.dumps(yaml.safe_load(open('$file'))))" 2>/dev/null
    else
        echo "{}"
    fi
}

# Get YAML value and export as environment variable
yaml_export() {
    local file="$1"
    local key="$2"
    local var_name="$3"
    local default="${4:-}"
    export "$var_name"="$(yaml_get "$file" "$key" "$default")"
}

