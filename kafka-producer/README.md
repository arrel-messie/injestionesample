# Kafka Producer - Data Generator

Development tool to generate test data and send it to Kafka.

## Objective

This module generates payment transactions (Protobuf format) and sends them to a Kafka topic. It is used for:
- Testing Kafka infrastructure locally
- Generating test data for Druid ingestion
- Validating Protobuf schemas

## Quick Start

### Prerequisites

- Java 11+
- Maven 3.6+
- Accessible Kafka cluster (local or remote)
- Schema Registry (optional, for Confluent)

### Compilation

```bash
cd kafka-producer
mvn clean package
```

### Execution

```bash
# With default configuration
java -jar target/kafka-producer-1.0.0.jar

# Or with Maven
mvn exec:java -Dexec.mainClass="com.kafka.injector.producer.TransactionProducer"
```

## Configuration

The `src/main/resources/application.properties` file contains the configuration:

```properties
# Kafka Configuration
kafka.bootstrap.servers=localhost:9092
kafka.topic.name=settlement-transactions-dev
kafka.client.id=transaction-producer

# Schema Registry Configuration
schema.registry.url=http://localhost:8085

# Producer Behavior
producer.send.interval.seconds=30
producer.send.count=-1  # -1 = infinite
producer.random.data.enabled=true
```

### Usage with local infrastructure

If you use `../infrastructure/docker-compose.yml`:

```bash
# 1. Start infrastructure
cd ../infrastructure
docker-compose up -d

# 2. In another terminal, run the producer
cd ../kafka-producer
mvn clean package exec:java
```

## Structure

```
kafka-producer/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/kafka/injector/producer/
│   │   │       └── TransactionProducer.java
│   │   ├── proto/
│   │   │   └── settlement_transaction.proto
│   │   └── resources/
│   │       ├── application.properties
│   │       └── logback.xml
│   └── test/
│       └── java/
├── pom.xml
└── target/                            # Generated (in .gitignore)
```

## Configuration Options

### Producer Behavior

- `producer.send.interval.seconds`: Interval between each message (default: 30)
- `producer.send.count`: Number of messages to send (-1 = infinite)
- `producer.random.data.enabled`: Generate random data (true/false)

### Kafka Producer Settings

All standard Kafka producer parameters are configurable:
- `producer.acks`: all, 1, 0
- `producer.retries`: Number of retries
- `producer.compression.type`: snappy, gzip, lz4, etc.
- `producer.batch.size`: Batch size
- `producer.linger.ms`: Delay before sending batch

## Data Format

The producer generates messages in Protobuf format defined in `settlement_transaction.proto`:

The production schema is in `../druid-ingestion/schemas/proto/settlement_transaction.proto`.

## Tests

**TODO:** Add unit and integration tests.

## Logs

Logs are configured in `logback.xml`:
- Console: INFO
- File: `logs/transaction-producer.log` (daily rotation)
- Logger `com.kafka.injector`: DEBUG

## Troubleshooting

### Kafka connection error
```
Error sending message: Connection refused
```
- Check that Kafka is started
- Check `kafka.bootstrap.servers` in `application.properties`

### Schema Registry error
```
Error registering schema
```
- Check that Schema Registry is started
- Check `schema.registry.url`
- Or disable Schema Registry if not used

### Messages not received
- Check that the topic exists
- Check Kafka permissions (SASL/SSL if enabled)
- Check producer logs

## Useful Links

- [Kafka Producer Documentation](https://kafka.apache.org/documentation/#producerconfigs)
- [Confluent Schema Registry](https://docs.confluent.io/platform/current/schema-registry/index.html)
- [Druid Ingestion Module](../druid-ingestion/)
