# Druid Kafka Ingestion

Main module for Kafka to Apache Druid data ingestion using Protobuf schemas stored on S3.

## Objective

This module configures and deploys Druid supervisors for Kafka data ingestion in production.

## Quick Start

### Local testing with Docker Compose

```bash
cd druid-ingestion
make test-local      # Setup Docker Compose environment
# Then in another terminal: generate data with kafka-producer
# Then: make deploy-dev
```

### Production deployment

```bash
cd druid-ingestion
make deploy-dev      # Deploy to DEV
make deploy-staging  # Deploy to STAGING
make deploy-prod     # Deploy to PRODUCTION
```

## Prerequisites

- `envsubst` (gettext-base package)
- `jq` (JSON parser)
- `protoc` (Protobuf compiler)
- `curl` (HTTP client)
- `aws-cli` (optional, for manual rollback)

```bash
make check-deps      # Check dependencies
make install-deps    # Install dependencies (Ubuntu/Debian)
```

## Structure

```
druid-ingestion/
├── config/              # Environment configurations
│   ├── dev.env
│   ├── staging.env
│   ├── prod.env
│   ├── dev.env.example  # Template for dev.env
│   ├── dimensions.json
│   ├── metrics.json
│   ├── transforms.json
│   └── index-spec.json
├── druid-specs/         # Druid supervisor specifications
│   ├── templates/      # Template files
│   │   └── kafka-supervisor.json
│   └── generated/       # Generated supervisor specs (gitignored)
│       └── supervisor-spec-*.json
├── schemas/             # Protobuf schemas (source of truth)
│   └── proto/
│       └── settlement_transaction.proto
├── scripts/             # Deployment scripts
│   ├── compile-proto.sh
│   ├── deploy-supervisor.sh
│   └── rollback-schema.sh
└── docs/                # Documentation
    ├── SETUP.md
    └── DEPLOYMENT.md
```

## Configuration

### 1. Environment configuration

```bash
# Copy template for development
cp config/dev.env.example config/dev.env

# Edit with your values
vim config/dev.env
```

**WARNING:** Credentials must never be committed. Use:
- Environment variables at runtime
- GitLab CI/CD Variables (for production)
- Secret managers (AWS Secrets Manager, Vault, etc.)

### 2. Required variables

For each environment, the following variables are mandatory:
- `KAFKA_BOOTSTRAP_SERVERS`
- `KAFKA_TOPIC`
- `DATASOURCE_NAME`
- `DRUID_OVERLORD_URL`

## Available Commands

### Deployment
```bash
make deploy-dev      # Deploy to DEV
make deploy-staging  # Deploy to STAGING
make deploy-prod     # Deploy to PRODUCTION
```

### Validation
```bash
make validate        # Validate JSON configuration
make compile         # Compile Protobuf schemas
make test-template ENV=dev  # Test template generation
```

### Monitoring
```bash
make status ENV=dev  # Supervisor status
make logs ENV=dev    # Supervisor logs
```

### Rollback
```bash
make rollback ENV=prod VERSION=abc123f
```

### Utilities
```bash
make check-deps      # Check dependencies
make clean           # Clean generated files
make list-schemas    # List versions on S3
```

## Documentation

- [Installation guide](docs/SETUP.md)
- [Deployment guide](docs/DEPLOYMENT.md)
- [Monitoring and validation](docs/MONITORING.md)
- [Partitioning configuration](docs/PARTITIONING.md)
- [Local testing with Docker Compose](docs/TESTING_LOCAL.md)

## Normalization Transformations

The module automatically applies transformations to normalize string fields to uppercase while preserving original proto field names:

- `tx_type`: Normalized to uppercase (replaces original value)
- `status`: Normalized to uppercase (replaces original value)
- `currency`: Normalized to uppercase (replaces original value)
- `payer_access_manager_bic`: Normalized to uppercase
- `payee_access_manager_bic`: Normalized to uppercase
- `reason_code`: Normalized to uppercase (replaces original value)
- `payment_type_code`: Normalized to uppercase (replaces original value)

These transformations improve query consistency and performance while keeping column names identical to the Protobuf schema.

See [MONITORING.md](docs/MONITORING.md) for more details.

## Secondary Partitioning

The module uses secondary partitioning on `payer_access_manager_id` (cardinality: 5500, used in 80% of queries) to optimize performance.

See [PARTITIONING.md](docs/PARTITIONING.md) for more details.

## GitOps Workflow

```
develop  → Auto-deploy DEV
   ↓
staging  → Auto-deploy STAGING
   ↓
main     → Manual deploy PRODUCTION
```

## Security

- Credentials stored in GitLab CI/CD Variables (masked)
- S3 descriptors accessible read-only by Druid
- SASL_SSL enabled for Kafka
- Required variables validation before deployment
- Production deployments require explicit confirmation

## Troubleshooting

### Supervisor does not start
1. Check descriptor on S3
2. Check IAM permissions
3. Check Druid logs: `make logs ENV=dev`

### Protobuf parsing errors
1. Check `protoMessageType`
2. Check compilation with `make compile`

### Invalid JSON
```bash
jq empty druid-specs/generated/supervisor-spec-dev.json  # Validate
```
