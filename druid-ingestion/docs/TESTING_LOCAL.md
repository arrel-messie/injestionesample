# Local Testing with Docker Compose

Complete guide for testing Druid ingestion with local Docker Compose infrastructure.

## Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- 8GB+ RAM available
- Free ports: 2181, 8081-8095, 9092, 8888

## Step 1: Start infrastructure (2 minutes)

```bash
# From project root
cd infrastructure

# Create .env file if needed
if [ ! -f .env ]; then
  cat > .env << EOF
ZOO_MY_ID=1
KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092
DRUID_VERSION=30.0.0
EOF
fi

# Start all services
docker-compose up -d

# Wait for all services to be ready (~1-2 minutes)
echo "Waiting for services to start..."
sleep 30

# Check status
docker-compose ps
```

**Services started:**
- Zookeeper (port 2181)
- Kafka (port 9092)
- Schema Registry (port 8085) - optional
- Druid Coordinator (port 8081)
- Druid Broker (port 8082)
- Druid Historical (port 8083)
- Druid MiddleManager (port 8091)
- Druid Router (port 8888) - optional
- AKHQ (port 8084) - optional

**Note:** Druid uses embedded Derby for metadata storage (no PostgreSQL needed).

## Step 2: Compile Protobuf schema (30 seconds)

```bash
cd ../druid-ingestion
make compile
```

This generates `schemas/compiled/settlement_transaction.desc`

## Step 3: Configure for local environment (1 minute)

The template uses a `PROTO_DESCRIPTOR_PATH` variable that can point to:
- A local file: `file:///opt/shared/schemas/settlement_transaction.desc`
- An S3 file: `s3://bucket/schemas/version/file.desc` (default if not defined)

```bash
# Copy local configuration
cp config/dev.env.local config/dev.env

# The dev.env.local file already contains:
# - PROTO_DESCRIPTOR_PATH="file:///opt/shared/schemas/settlement_transaction.desc"
# - KAFKA_BOOTSTRAP_SERVERS="localhost:9092"
# - DRUID_OVERLORD_URL="http://localhost:8090"
# - No SASL (KAFKA_SASL_JAAS_CONFIG empty)
```

The template will automatically generate the correct path based on the environment variable.

## Step 4: Create Kafka topic (30 seconds)

```bash
# Create topic for transactions
docker exec kafka kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --topic settlement-transactions-dev \
  --partitions 3 \
  --replication-factor 1

# Verify topic is created
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092
```

## Step 5: Generate test data (1 minute)

```bash
# In another terminal
cd kafka-producer

# Compile and execute
mvn clean package exec:java

# Producer will generate messages every 30 seconds
# Let it run for a few minutes to generate data
```

## Step 6: Deploy Druid ingestion (1 minute)

The template automatically uses the `PROTO_DESCRIPTOR_PATH` variable defined in `dev.env.local`.

```bash
# The dev.env.local file already contains:
# PROTO_DESCRIPTOR_PATH="file:///opt/shared/schemas/settlement_transaction.desc"

# Deploy (script will automatically use the correct path)
make deploy-dev
```

The template will generate the spec with `file://` path for local testing, or `s3://` for production based on the environment variable.

## Step 7: Verify ingestion (1 minute)

### Check supervisor

```bash
# Supervisor status
make status ENV=dev

# Logs
make logs ENV=dev
```

### Access web interfaces

- **Druid Console**: http://localhost:8888
- **Druid Overlord**: http://localhost:8090
- **AKHQ (Kafka UI)**: http://localhost:8084

### Verify ingested data

```bash
# Via curl
curl -X POST http://localhost:8082/druid/v2/sql \
  -H 'Content-Type: application/json' \
  -d '{
    "query": "SELECT COUNT(*) as total FROM idm_settlement_snapshot_dev"
  }'
```

## Docker Compose configuration for schemas

For Druid to access the Protobuf descriptor, the volume is already configured in `infrastructure/docker-compose.yml`:

```yaml
# In each Druid service (coordinator, historical, middlemanager)
volumes:
  - druid_shared:/opt/shared
  - ../druid-ingestion/schemas/compiled:/opt/shared/schemas:ro
```

The `config/dev.env.local` file is already configured to use the local path.

## Complete test script

Use the provided script:

```bash
cd druid-ingestion
make test-local
```

This script automates all the steps above.

## Troubleshooting

### Druid cannot find descriptor

**Problem:** `descriptorFilePath` points to S3 but we're in local mode.

**Solution:**
1. Use shared Docker volume (already configured)
2. Or use LocalStack to simulate S3

### Kafka is not accessible

```bash
# Check that Kafka is started
docker-compose ps kafka

# Check logs
docker-compose logs kafka

# Test connection
docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092
```

### Druid does not start

```bash
# Check logs
docker-compose logs coordinator
docker-compose logs middlemanager
docker-compose logs historical
```

### Supervisor does not consume

```bash
# Verify topic contains messages
docker exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic settlement-transactions-dev \
  --from-beginning \
  --max-messages 1

# Check supervisor logs
make logs ENV=dev
```

## Cleanup

```bash
# Stop all services
cd infrastructure
docker-compose down

# Remove volumes (WARNING: data loss)
docker-compose down -v

# Clean generated files
cd ../druid-ingestion
make clean
```

## Next Steps

Once local testing is successful:
1. Configure GitLab CI/CD for production
2. Configure environment variables
3. Deploy to staging then production
