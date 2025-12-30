#!/bin/bash
# scripts/compile-proto.sh
# Script pour compiler localement les fichiers .proto en .desc

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROTO_DIR="$PROJECT_ROOT/schemas/proto"
OUTPUT_DIR="$PROJECT_ROOT/schemas/compiled"

echo "🔧 Compilation des schémas Protobuf..."
echo "📂 Source: $PROTO_DIR"
echo "📂 Output: $OUTPUT_DIR"

# Créer le répertoire de sortie
mkdir -p "$OUTPUT_DIR"

# Vérifier que protoc est installé
if ! command -v protoc &> /dev/null; then
    echo "❌ Erreur: protoc n'est pas installé"
    echo "Installation:"
    echo "  - macOS: brew install protobuf"
    echo "  - Ubuntu/Debian: apt-get install protobuf-compiler"
    echo "  - Autre: https://grpc.io/docs/protoc-installation/"
    exit 1
fi

echo "✅ protoc version: $(protoc --version)"

# Compiler tous les fichiers .proto
compiled_count=0
for proto_file in "$PROTO_DIR"/*.proto; do
    if [ -f "$proto_file" ]; then
        filename=$(basename "$proto_file" .proto)
        output_file="$OUTPUT_DIR/${filename}.desc"
        
        echo "📝 Compilation: $filename.proto → ${filename}.desc"
        
        protoc \
            --descriptor_set_out="$output_file" \
            --include_imports \
            --proto_path="$PROTO_DIR" \
            "$proto_file"
        
        if [ $? -eq 0 ]; then
            echo "   ✅ Succès"
            ((compiled_count++))
        else
            echo "   ❌ Échec"
            exit 1
        fi
    fi
done

echo ""
echo "✅ Compilation terminée: $compiled_count fichier(s)"
echo "📦 Fichiers générés dans: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"
