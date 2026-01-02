#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

check_command protoc || {
    echo "ERROR: protoc not found" >&2
    echo "  macOS: brew install protobuf" >&2
    echo "  Ubuntu: apt-get install protobuf-compiler" >&2
    exit 1
}

PROTO_DIR="$MODULE_ROOT/schemas/proto"
OUTPUT_DIR="$MODULE_ROOT/schemas/compiled"

check_dir "$PROTO_DIR"
mkdir -p "$OUTPUT_DIR"

for proto in "$PROTO_DIR"/*.proto; do
    [ -f "$proto" ] || continue
    name=$(basename "$proto" .proto)
    echo "Compiling: $name"
    protoc --descriptor_set_out="$OUTPUT_DIR/$name.desc" \
           --include_imports \
           --proto_path="$PROTO_DIR" \
           "$proto"
done

echo "Compiled to $OUTPUT_DIR"
