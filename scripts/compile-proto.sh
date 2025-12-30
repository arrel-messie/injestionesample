#!/bin/bash
# scripts/compile-proto.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTO_DIR="$(dirname "$SCRIPT_DIR")/schemas/proto"
OUTPUT_DIR="$(dirname "$SCRIPT_DIR")/schemas/compiled"

command -v protoc >/dev/null 2>&1 || {
    echo "protoc not found. Install it:" >&2
    echo "  brew install protobuf" >&2
    echo "  apt-get install protobuf-compiler" >&2
    exit 1
}

mkdir -p "$OUTPUT_DIR"

compiled=0
for proto in "$PROTO_DIR"/*.proto; do
    [ -f "$proto" ] || continue
    name=$(basename "$proto" .proto)
    protoc --descriptor_set_out="$OUTPUT_DIR/$name.desc" \
           --include_imports \
           --proto_path="$PROTO_DIR" \
           "$proto" && ((compiled++))
done

echo "$compiled proto files compiled to $OUTPUT_DIR"