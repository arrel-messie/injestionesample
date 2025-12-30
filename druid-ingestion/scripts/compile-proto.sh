#!/bin/bash
# compile-proto.sh - Compile Protobuf schemas to descriptor files

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

PROTO_DIR="$MODULE_ROOT/schemas/proto"
OUTPUT_DIR="$MODULE_ROOT/schemas/compiled"

check_command protoc || {
    echo "ERROR: protoc not found. Please install it:" >&2
    echo "  macOS:   brew install protobuf" >&2
    echo "  Ubuntu:  apt-get install protobuf-compiler" >&2
    echo "  RHEL:    yum install protobuf-compiler" >&2
    exit 1
}

check_dir "$PROTO_DIR"
mkdir -p "$OUTPUT_DIR"

compiled=0
errors=0

for proto in "$PROTO_DIR"/*.proto; do
    [ -f "$proto" ] || continue
    
    name=$(basename "$proto" .proto)
    output_file="$OUTPUT_DIR/$name.desc"
    
    echo "Compiling: $(basename "$proto")"
    
    if protoc --descriptor_set_out="$output_file" \
              --include_imports \
              --proto_path="$PROTO_DIR" \
              "$proto" 2>&1; then
        ((compiled++))
    else
        echo "ERROR: Failed to compile $proto" >&2
        ((errors++))
    fi
done

[ $errors -gt 0 ] && {
    echo "ERROR: Failed to compile $errors proto file(s)" >&2
    exit 1
}

echo "Successfully compiled $compiled proto file(s) to $OUTPUT_DIR"
