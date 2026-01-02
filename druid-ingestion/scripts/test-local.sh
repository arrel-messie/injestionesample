#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$MODULE_ROOT")"

command -v docker-compose >/dev/null 2>&1 || command -v docker >/dev/null 2>&1 || {
    echo "ERROR: Docker Compose not installed" >&2
    exit 1
}

cd "$PROJECT_ROOT/infrastructure"

[ ! -f .env ] && cat > .env <<EOF
ZOO_MY_ID=1
KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092
DRUID_VERSION=30.0.0
EOF

echo "Starting services..."
docker-compose up -d
sleep 30
docker-compose ps

echo "Compiling Protobuf schema..."
cd "$MODULE_ROOT"
make compile

DESC_FILE="$MODULE_ROOT/schemas/compiled/settlement_transaction.desc"
[ ! -f "$DESC_FILE" ] && { echo "ERROR: Descriptor not found" >&2; exit 1; }

echo "Creating Kafka topic..."
docker exec kafka kafka-topics --create \
    --bootstrap-server localhost:9092 \
    --topic settlement-transactions-dev \
    --partitions 3 \
    --replication-factor 1 \
    2>/dev/null || true

[ ! -f "$MODULE_ROOT/config/dev.env" ] && \
    cp "$MODULE_ROOT/config/dev.env.example" "$MODULE_ROOT/config/dev.env"

echo "Infrastructure ready"
echo "  Druid Console: http://localhost:8888"
echo "  Druid Overlord: http://localhost:8090"
echo "  AKHQ: http://localhost:8084"

