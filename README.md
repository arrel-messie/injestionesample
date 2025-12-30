# Ingestion Sample - Complete Project

Complete solution for Kafka to Apache Druid data ingestion with Protobuf and S3.

## Overview

This project is organized into **three distinct modules**:

1. **[druid-ingestion](druid-ingestion/)** - Main Kafka → Druid ingestion module (production)
2. **[kafka-producer](kafka-producer/)** - Test data generator (development)
3. **[infrastructure](infrastructure/)** - Docker stack for local environment

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Architecture                          │
│                                                          │
│  kafka-producer (test data)                             │
│       │                                                  │
│       │ generates                                       │
│       ▼                                                  │
│  Kafka Topic (Protobuf)                                 │
│       │                                                  │
│       │ consumes                                        │
│       ▼                                                  │
│  Druid Supervisor (via druid-ingestion)                 │
│       │                                                  │
│       │ reads schema from                               │
│       ▼                                                  │
│  S3 Bucket (descriptors .desc)                          │
│       │                                                  │
│       │ versioned via                                   │
│       ▼                                                  │
│  GitLab CI/CD Pipeline                                  │
└─────────────────────────────────────────────────────────┘
```

## Quick Start

### Scenario 1: Complete local testing with Docker Compose

```bash
# 1. Start local infrastructure (Kafka, Druid, Schema Registry)
cd infrastructure
docker-compose up -d

# Wait for all services to be ready (~1-2 minutes)
docker-compose ps

# 2. Compile Protobuf schema
cd ../druid-ingestion
make compile

# 3. Configure for local environment
cp config/dev.env.local config/dev.env

# 4. In another terminal: Generate test data
cd kafka-producer
mvn clean package exec:java

# 5. Deploy Druid ingestion
cd ../druid-ingestion
make deploy-dev

# 6. Verify
make status ENV=dev
# Access http://localhost:8888 for Druid console
```

### Scenario 2: Deploy to production (DevOps)

```bash
cd druid-ingestion
make deploy-prod
```

### Scenario 3: Producer development only

```bash
cd kafka-producer
mvn clean package exec:java
```

## Project Structure

```
injestionesample/
├── README.md                    # This file
├── CHANGELOG.md                 # Global changelog
├── LICENSE                      # License
│
├── druid-ingestion/             # MAIN MODULE
│   ├── README.md               # Module documentation
│   ├── Makefile                # Deployment commands
│   ├── config/                 # Environment configurations
│   │   ├── dev.env.local       # Config for local Docker Compose
│   │   ├── dimensions.json     # Druid dimensions
│   │   ├── metrics.json        # Druid metrics
│   │   ├── transforms.json     # Data transformations
│   │   └── index-spec.json     # Indexing configuration
│   ├── schemas/                # Protobuf schemas (source of truth)
│   ├── druid-specs/            # Druid templates
│   ├── scripts/                # Deployment scripts
│   └── docs/                   # Module documentation
│
├── kafka-producer/              # TEST MODULE
│   ├── README.md               # Module documentation
│   ├── pom.xml                 # Maven configuration
│   └── src/                    # Java source code
│
└── infrastructure/              # INFRASTRUCTURE
    ├── README.md               # Module documentation
    ├── docker-compose.yml      # Complete stack
    └── .env.example            # Configuration template
```

## Documentation

### By module

- **[druid-ingestion/README.md](druid-ingestion/README.md)** - Druid ingestion guide
- **[kafka-producer/README.md](kafka-producer/README.md)** - Kafka producer guide
- **[infrastructure/README.md](infrastructure/README.md)** - Local infrastructure guide

## Prerequisites

### For druid-ingestion
- `envsubst`, `jq`, `protoc`, `curl`, `aws-cli` (optional)
- Access to a Druid cluster
- Access to a Kafka cluster with SASL_SSL
- S3 bucket for schemas (or local file for development)

### For kafka-producer
- Java 11+
- Maven 3.6+
- Accessible Kafka cluster

### For infrastructure
- Docker 20.10+
- Docker Compose 2.0+
- 8GB+ RAM available

## Security

- **WARNING:** Secrets must never be committed
- Use `.env.example` as template
- Environment variables at runtime
- GitLab CI/CD Variables for production
- Secret managers (AWS Secrets Manager, Vault) recommended

## Useful Commands

### Infrastructure
```bash
cd infrastructure
docker-compose up -d          # Start all services
docker-compose ps             # Check status
docker-compose down           # Stop
docker-compose logs -f        # Real-time logs
docker-compose logs -f kafka  # Specific service logs
```

### Kafka Producer
```bash
cd kafka-producer
mvn clean package             # Compile
mvn exec:java                 # Execute
```

### Druid Ingestion
```bash
cd druid-ingestion
make deploy-dev               # Deploy to DEV
make status ENV=dev           # Status
make logs ENV=dev             # Logs
make rollback ENV=prod VERSION=abc123f  # Rollback
```

## Troubleshooting

See each module's README for specific troubleshooting:
- [druid-ingestion troubleshooting](druid-ingestion/README.md#troubleshooting)
- [kafka-producer troubleshooting](kafka-producer/README.md#troubleshooting)
- [infrastructure troubleshooting](infrastructure/README.md#troubleshooting)

## Development Workflow

```
1. Modify Proto schema
   └─> druid-ingestion/schemas/proto/

2. Compile schema
   └─> cd druid-ingestion && make compile

3. Test locally
   └─> infrastructure/docker-compose.yml
   └─> kafka-producer to generate data
   └─> druid-ingestion to deploy

4. Deploy to production
   └─> cd druid-ingestion && make deploy-prod
```

## License

Proprietary - Internal use only

## Team

Your Data Engineering Team
