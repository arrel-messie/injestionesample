# Quick Start

This guide helps you get started quickly with the Druid ingestion project.

## Option 1: Local testing with Docker Compose (Recommended for beginners)

### Step 1: Automatic setup (2 minutes)

```bash
cd druid-ingestion
make test-local
```

This script will:
- Start all Docker Compose services
- Compile Protobuf schema
- Create Kafka topic
- Configure local environment

### Step 2: Generate test data (1 minute)

```bash
# In another terminal
cd kafka-producer
mvn clean package exec:java
```

The producer generates messages every 30 seconds. Let it run for a few minutes.

### Step 3: Deploy Druid ingestion (1 minute)

The template automatically uses the `PROTO_DESCRIPTOR_PATH` variable defined in `dev.env.local`.

```bash
make deploy-dev
```

The template will generate the spec with `file://` path for local testing, or `s3://` for production based on the environment variable.

### Step 4: Verify (30 seconds)

```bash
# Check status
make status ENV=dev

# Access web interfaces
open http://localhost:8888  # Druid Console
open http://localhost:8090  # Druid Overlord
open http://localhost:8084  # AKHQ (Kafka UI)
```

See [TESTING_LOCAL.md](druid-ingestion/docs/TESTING_LOCAL.md) for the complete guide.

## Option 2: Production deployment (GitLab CI/CD)

### Step 1: Extraction (30 seconds)

```bash
unzip druid-kafka-ingestion.zip
cd druid-kafka-ingestion
```

## Step 2: Check dependencies (30 seconds)

```bash
make check-deps
```

**Required dependencies** (already present on most Linux systems):
- `envsubst` (gettext-base) - Pre-installed
- `jq` (~3MB) - Installation: `apt-get install jq`
- `protoc` - Installation: `apt-get install protobuf-compiler`
- `curl` - Pre-installed

**Quick installation Ubuntu/Debian:**
```bash
make install-deps-ubuntu
```

**Quick installation macOS:**
```bash
make install-deps-macos
```

## Step 3: GitLab configuration (2 minutes)

1. **Create a new GitLab project** and push the code

2. **Configure CI/CD variables**
   
   In `Settings > CI/CD > Variables`:
   
   | Variable | Value | Masked |
   |----------|--------|--------|
   | `AWS_ACCESS_KEY_ID` | `AKIA...` | No |
   | `AWS_SECRET_ACCESS_KEY` | `secret...` | Yes |
   | `S3_BUCKET` | `my-company-druid-schemas` | No |
   | `S3_REGION` | `eu-west-1` | No |
   | `KAFKA_PROD_USER` | `prod-user` | No |
   | `KAFKA_PROD_PASSWORD` | `prod-pass` | Yes |

3. **Create branches**
   ```bash
   git checkout -b develop
   git push origin develop
   git checkout -b staging
   git push origin staging
   ```

## Step 4: Adapt configurations (2 minutes)

### 1. Modify `config/dev.env`
```bash
vim config/dev.env

# Adapt these values:
KAFKA_BOOTSTRAP_SERVERS="your-kafka:9092"
DRUID_OVERLORD_URL="http://your-druid:8090"
PROTO_MESSAGE_TYPE="your.package.MessageType"
```

### 2. Modify `schemas/proto/settlement_transaction.proto`
Adapt according to your data structure (currently: `PaymentTransactionEvent`)

### 3. Modify JSON configuration files
- `config/dimensions.json` - Druid dimensions
- `config/metrics.json` - Druid metrics
- `config/transforms.json` - Data transformations
- `config/index-spec.json` - Indexing configuration

## Step 5: First deployment (30 seconds)

```bash
# Commit and push to develop
git add config/ schemas/
git commit -m "Configure for our environment"
git push origin develop

# GitLab CI/CD pipeline will automatically:
# - Compile .proto to .desc
# - Upload to S3
# - Deploy to DEV
```

## Step 6: Verification (30 seconds)

**Check GitLab pipeline:**
- Go to CI/CD > Pipelines
- All jobs must be green

**Check Druid supervisor:**
```bash
make status ENV=dev
```

Or via console: `http://your-druid:8090/unified-console.html#supervisors`

## Essential Commands

```bash
# Deployment
make deploy-dev          # Deploy to DEV
make deploy-staging      # Deploy to STAGING
make deploy-prod         # Deploy to PRODUCTION

# Validation
make validate            # Validate configs
make compile             # Compile .proto
make test-template ENV=dev  # Test generation

# Monitoring
make status ENV=dev      # Supervisor status
make logs ENV=dev        # Supervisor logs

# Rollback
make rollback ENV=prod VERSION=abc123f
```

## Local testing before GitLab

### With Docker Compose (Recommended)

```bash
# 1. Start infrastructure
cd infrastructure
docker-compose up -d

# 2. Compile and validate
cd ../druid-ingestion
make compile
make validate

# 3. Test template generation
make test-template ENV=dev

# 4. Generate test data
cd ../kafka-producer
mvn clean package exec:java

# 5. Deploy ingestion
cd ../druid-ingestion
make deploy-dev
```

### Without Docker Compose

```bash
# Compile locally
make compile

# Test template generation
make test-template ENV=dev

# Validate JSON
make validate
```

## envsubst syntax (used in templates)

The project uses `envsubst` to substitute variables:

```json
{
  "topic": "${KAFKA_TOPIC}",
  "taskCount": ${TASK_COUNT:-10}
}
```

**Syntax:**
- `${VAR}` - Required variable
- `${VAR:-default}` - Variable with default value

## Quick Troubleshooting

### envsubst not found
```bash
sudo apt-get install gettext-base
```

### jq not found
```bash
sudo apt-get install jq
```

### Supervisor does not start
```bash
# Check logs
make logs ENV=dev

# Check schema on S3
make list-schemas
```

### Invalid JSON
```bash
# Test locally
make test-template ENV=dev
jq . test-output.json
```

## Complete Documentation

- **README.md** - Project overview
- **druid-ingestion/README.md** - Ingestion module documentation
- **druid-ingestion/docs/SETUP.md** - Detailed installation
- **druid-ingestion/docs/DEPLOYMENT.md** - Deployment procedures
- **druid-ingestion/docs/MONITORING.md** - Monitoring and validation
- **druid-ingestion/docs/PARTITIONING.md** - Partitioning configuration
- **infrastructure/README.md** - Docker Compose infrastructure guide

## Advantages of this solution

- **Zero external dependency** - Native Linux tools only  
- **Industry standard** - envsubst used by Kubernetes, Docker  
- **Simple and fast** - No "magic", clear syntax  
- **Performant** - Very fast, lightweight Docker images  

---

**Ready to deploy? Let's go!**
