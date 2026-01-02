# Druid Kafka Ingestion

Main module for Kafka to Apache Druid data ingestion using Protobuf schemas stored on S3.

## Objective

This module configures and deploys Druid supervisors for Kafka data ingestion in production.

## Quick Start

### Build the application

```bash
cd druid-ingestion
mvn clean package
```

### Production deployment

```bash
# Build and deploy
mvn clean package
java -jar target/druid-ingestion-1.0.0.jar deploy -e dev      # Deploy to DEV
java -jar target/druid-ingestion-1.0.0.jar deploy -e staging  # Deploy to STAGING
java -jar target/druid-ingestion-1.0.0.jar deploy -e prod     # Deploy to PRODUCTION
```

## Prerequisites

- **Java 11+** (required)
- **Maven 3.6+** (required)
- `protoc` (Protobuf compiler, for schema compilation)
- `jq` (optional, for JSON pretty-printing in test-template)

```bash
# Check Java and Maven
java -version
mvn -version

# Install dependencies (Ubuntu/Debian)
sudo apt-get update && sudo apt-get install -y openjdk-11-jdk maven protobuf-compiler
```

## Structure

```
druid-ingestion/
├── config/              # Configuration files
│   ├── dev.env          # Environment variables (dev)
│   ├── staging.env      # Environment variables (staging)
│   ├── prod.env         # Environment variables (prod)
│   └── schema.json      # Unified schema definition (dimensions, metrics, transforms, index)
├── druid-specs/         # Generated supervisor specs (gitignored)
│   └── generated/
│       └── supervisor-spec-*.json
├── schemas/             # Protobuf schemas
│   ├── proto/
│   │   └── settlement_transaction.proto
│   └── compiled/
│       └── settlement_transaction.desc
├── src/main/java/       # Java application source
│   └── com/company/druid/ingestion/
│       └── DruidIngestion.java       # Main application (single file)
└── docs/                # Documentation
    ├── SETUP.md
    └── DEPLOYMENT.md
```

## Configuration

### Architecture

The supervisor spec is built directly in Java code using:
- **`config/{env}.env`**: Environment-specific configuration (Kafka, Druid URLs, etc.)
- **`config/schema.json`**: Schema definitions (dimensions, metrics, transforms, index-spec)

The Java application constructs the complete Druid supervisor spec JSON programmatically.

### 1. Environment configuration

Environment-specific variables are stored in `config/{env}.env` files:

```bash
# Edit environment configuration
vim config/dev.env
```

**WARNING:** Credentials must never be committed. Use:
- Environment variables at runtime
- GitLab CI/CD Variables (for production)
- Secret managers (AWS Secrets Manager, Vault, etc.)

### 2. Schema configuration

The `config/schema.json` file contains the schema definitions (dimensions, metrics, transforms, index-spec) that are shared across all environments.

### 3. Required variables

For each environment, the following variables are mandatory in `config/{env}.env`:
- `DRUID_OVERLORD_URL` (for deployment)

## Available Commands

### Build

```bash
mvn clean package
```

### Deployment

```bash
# Deploy to environment
java -jar target/druid-ingestion-1.0.0.jar deploy -e dev      # Deploy to DEV
java -jar target/druid-ingestion-1.0.0.jar deploy -e staging  # Deploy to STAGING
java -jar target/druid-ingestion-1.0.0.jar deploy -e prod      # Deploy to PRODUCTION
```

### Build supervisor spec

```bash
# Build spec for testing
java -jar target/druid-ingestion-1.0.0.jar build -e dev -o druid-specs/generated/test-output.json

# View generated spec
jq . druid-specs/generated/test-output.json
```

### Monitoring

```bash
# Get supervisor status
java -jar target/druid-ingestion-1.0.0.jar status -e dev
```

### Compile Protobuf schemas

```bash
mvn generate-sources
# or
mvn clean package  # Compiles protos automatically
```

### Help

```bash
java -jar target/druid-ingestion-1.0.0.jar --help
java -jar target/druid-ingestion-1.0.0.jar deploy --help
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
