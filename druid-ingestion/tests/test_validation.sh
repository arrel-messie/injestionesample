#!/usr/bin/env bash
# Tests basiques de validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "${ROOT_DIR}/lib/logger.sh"

test_count=0
pass_count=0
fail_count=0

test_pass() {
    ((test_count++))
    ((pass_count++))
    echo "✅ PASS: $1"
}

test_fail() {
    ((test_count++))
    ((fail_count++))
    echo "❌ FAIL: $1"
}

test_parse_opts() {
    echo "Testing parse_opts..."
    source "${ROOT_DIR}/druid-ingestion.sh" 2>/dev/null || true
    
    parse_opts -e dev -o /tmp/test.json
    [[ "$ENV" == "dev" ]] && test_pass "parse_opts: ENV" || test_fail "parse_opts: ENV"
    [[ "$OUTPUT" == "/tmp/test.json" ]] && test_pass "parse_opts: OUTPUT" || test_fail "parse_opts: OUTPUT"
}

test_config_validation() {
    echo "Testing config validation..."
    source "${ROOT_DIR}/lib/config.sh"
    
    load_config "invalid" 2>/dev/null && test_fail "config: invalid env accepted" || test_pass "config: invalid env rejected"
    
    [[ -f "${ROOT_DIR}/config/dev.env" ]] && {
        load_config "dev" "${ROOT_DIR}/config" 2>/dev/null && test_pass "config: valid env loaded" || test_fail "config: valid env failed"
    } || echo "⚠️  SKIP: dev.env not found"
}

test_schema_validation() {
    echo "Testing schema validation..."
    [[ -f "${ROOT_DIR}/config/schema.json" ]] && {
        jq empty "${ROOT_DIR}/config/schema.json" 2>/dev/null && test_pass "schema: valid JSON" || test_fail "schema: invalid JSON"
    } || echo "⚠️  SKIP: schema.json not found"
}

main() {
    echo "=== Running basic validation tests ==="
    echo ""
    
    test_parse_opts
    test_config_validation
    test_schema_validation
    
    echo ""
    echo "=== Results ==="
    echo "Total: $test_count"
    echo "Passed: $pass_count"
    echo "Failed: $fail_count"
    
    [[ $fail_count -eq 0 ]] && exit 0 || exit 1
}

main "$@"

