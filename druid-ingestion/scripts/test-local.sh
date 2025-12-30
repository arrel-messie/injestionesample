#!/bin/bash
# test-local.sh - Setup local Docker Compose environment for testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$MODULE_ROOT")"

echo "=== Local Testing with Docker Compose ==="
echo ""

if ! command -v docker-compose >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker Compose is not installed" >&2
    exit 1
fi

echo "1. Starting Docker Compose infrastructure..."
cd "$PROJECT_ROOT/infrastructure"

if [ ! -f .env ]; then
    echo "Creating .env file..."
    cat > .env << EOF
ZOO_MY_ID=1
KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092
DRUID_VERSION=30.0.0
EOF
fi

echo "Starting services..."
docker-compose up -d

echo "Waiting for services to start (30 seconds)..."
sleep 30

echo "Checking status..."
docker-compose ps

echo ""
echo "2. Compiling Protobuf schema..."
cd "$MODULE_ROOT"
make compile

echo ""
echo "3. Verifying Protobuf descriptor..."
DESC_FILE="$MODULE_ROOT/schemas/compiled/settlement_transaction.desc"
if [ ! -f "$DESC_FILE" ]; then
    echo "ERROR: Descriptor file not found: $DESC_FILE" >&2
    echo "Make sure to run 'make compile' first" >&2
    exit 1
fi
echo "Descriptor found: $DESC_FILE"
echo "Note: Descriptor will be accessible via mounted volume in docker-compose.yml"

echo ""
echo "4. Creating Kafka topic..."
docker exec kafka kafka-topics --create \
    --bootstrap-server localhost:9092 \
    --topic settlement-transactions-dev \
    --partitions 3 \
    --replication-factor 1 \
    2>/dev/null || echo "Topic already exists"

echo ""
echo "5. Configuring local environment..."
if [ ! -f "$MODULE_ROOT/config/dev.env" ]; then
    cp "$MODULE_ROOT/config/dev.env.local" "$MODULE_ROOT/config/dev.env"
    echo "Created dev.env from dev.env.local"
else
    echo "dev.env already exists (not modified)"
fi

echo ""
echo "dev.env.local is configured to use descriptor from Docker mounted volume"
echo "via PROTO_DESCRIPTOR_PATH:"
echo "  file:///opt/shared/schemas/settlement_transaction.desc"

echo ""
echo "=== Infrastructure ready ==="
echo ""
echo "Next steps:"
echo "1. Generate test data: cd kafka-producer && mvn clean package exec:java"
echo "2. Deploy: make deploy-dev"
echo ""
echo "Web interfaces:"
echo "  - Druid Console: http://localhost:8888"
echo "  - Druid Overlord: http://localhost:8090"
echo "  - AKHQ: http://localhost:8084"

