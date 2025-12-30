# Local Infrastructure

Docker Compose stack for complete local development environment (Kafka, Druid, Schema Registry, etc.).

## Objective

This module provides a complete local infrastructure for:
- Developing and testing Druid ingestion
- Testing the kafka-producer
- Experimenting with Druid configurations
- Developing without depending on remote environments

## Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- At least 8GB RAM available
- Free ports: 2181, 8081-8095, 9092, etc.

### Installation

```bash
cd infrastructure

# Copy environment variables template
cp .env.example .env

# Edit .env with your values (optional)
vim .env

# Start all services
docker-compose up -d

# Check status
docker-compose ps
```

### Stop

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (WARNING: data loss)
docker-compose down -v
```

## Included Services

| Service | Port | Description |
|---------|------|-------------|
| Zookeeper | 2181 | Kafka coordination |
| Kafka | 9092 | Kafka broker |
| Schema Registry | 8085 | Confluent registry (optional) |
| Druid Coordinator | 8081 | Druid coordination |
| Druid Broker | 8082 | Query broker |
| Druid Historical | 8083 | Storage |
| Druid MiddleManager | 8091 | Indexing |
| Druid Router | 8888 | HTTP router (optional) |
| AKHQ | 8084 | Kafka interface (optional) |

**Note:** Druid uses embedded Derby for metadata storage (no PostgreSQL needed for local development).

## Configuration

### Environment variables

The `.env` file (created from `.env.example`) contains:

```bash
ZOO_MY_ID=1

KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092

DRUID_VERSION=30.0.0
```

**Note:** PostgreSQL is not needed - Druid uses embedded Derby for metadata storage in local development.

### Customization

You can modify `docker-compose.yml` to:
- Change versions
- Add services
- Modify configurations
- Adjust resources (CPU, RAM)

## Service Access

### Web interfaces

- **Druid Console**: http://localhost:8888
- **AKHQ (Kafka UI)**: http://localhost:8084
- **Schema Registry**: http://localhost:8085

### Connections

```bash
# Kafka
kafka-console-producer --bootstrap-server localhost:9092 --topic test

# Druid SQL
curl -X POST http://localhost:8082/druid/v2/sql \
  -H 'Content-Type: application/json' \
  -d '{"query":"SELECT 1"}'
```

## Usage with other modules

### 1. Test kafka-producer

```bash
# Terminal 1: Start infrastructure
cd infrastructure
docker-compose up -d

# Terminal 2: Run producer
cd ../kafka-producer
mvn clean package exec:java
```

### 2. Deploy Druid ingestion

```bash
# Use local test script (recommended)
cd ../druid-ingestion
make test-local

# Or manually:
# 1. Compile proto
make compile

# 2. Configure
cp config/dev.env.local config/dev.env

# 3. Create Kafka topic
docker exec kafka kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --topic settlement-transactions-dev \
  --partitions 3 \
  --replication-factor 1

# 4. Deploy
make deploy-dev
```

**Note:** For local testing, the Protobuf descriptor must be accessible via a shared Docker volume. See [druid-ingestion/docs/TESTING_LOCAL.md](../druid-ingestion/docs/TESTING_LOCAL.md) for details.

## Maintenance

### Clean logs

```bash
docker-compose logs --tail=100  # View last 100 lines
docker-compose logs -f service_name  # Follow logs for a service
```

### Restart a service

```bash
docker-compose restart kafka
docker-compose restart druid-coordinator
```

### View resource usage

```bash
docker stats
```

### Remove everything and start over

```bash
docker-compose down -v  # Remove volumes
docker-compose up -d    # Recreate everything
```

## Local Environment Limitations

- **Performance**: Not optimized for production
- **Persistence**: Data lost if volumes removed
- **Security**: No security enabled (dev only)
- **Resources**: Requires a lot of RAM/CPU

## Troubleshooting

### Port already in use

```bash
# Check which process uses the port
lsof -i :9092

# Change port in docker-compose.yml
ports:
  - "9093:9092"  # Use 9093 instead of 9092
```

### "Out of memory" error

```bash
# Reduce allocated resources in docker-compose.yml
deploy:
  resources:
    limits:
      memory: 2G  # Reduce if necessary
```

### Services not starting

```bash
# Check logs
docker-compose logs service_name

# Check dependencies (startup order)
docker-compose ps
```

### Corrupted data

```bash
# Remove volumes and restart
docker-compose down -v
docker-compose up -d
```

## Useful Links

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Druid Docker](https://docker.apache.org/druid/docker.html)
- [Confluent Platform Docker](https://docs.confluent.io/platform/current/installation/docker/)

## Notes

- Data is stored in named Docker volumes
- To access data: `docker volume ls` then `docker volume inspect <volume_name>`
- Configurations can be modified in `docker/` (create if necessary)
