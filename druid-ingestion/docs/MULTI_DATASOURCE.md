# Multi-Datasource Support

Ce document décrit comment utiliser l'application pour gérer plusieurs datasources Druid avec différents protos, topics et schemas.

## 🎯 Concept

L'application supporte maintenant plusieurs configurations :
- **Plusieurs protos** : `settlement_transaction.proto`, `payment_transaction.proto`, etc.
- **Plusieurs topics Kafka** : `settlement-tx-dev`, `payment-tx-dev`, etc.
- **Plusieurs datasources** : `settlement_ds`, `payment_ds`, etc.
- **Plusieurs schemas** : `schema-settlement.yml`, `schema-payment.yml`, etc.

## 📁 Structure de fichiers

### Configuration par datasource

```
config/
├── dev.env                          # Config par défaut pour dev
├── settlement-dev.env               # Config spécifique settlement (dev)
├── payment-dev.env                  # Config spécifique payment (dev)
├── schema.yml                       # Schema par défaut
├── schema-settlement.yml            # Schema spécifique settlement
├── schema-payment.yml               # Schema spécifique payment
└── schema-settlement-dev.yml        # Schema settlement pour dev (priorité)
```

### Priorité de chargement

1. **Config** : `{datasource}-{env}.env` > `{env}.env`
2. **Schema** : `schema-{datasource}-{env}.yml` > `schema-{datasource}.yml` > `schema-{env}.yml` > `schema.yml`

## 🔧 Utilisation

### Option 1: Fichier de config spécifique

Créez un fichier de config pour chaque datasource :

```bash
# config/settlement-dev.env
KAFKA_TOPIC=settlement-transactions-dev
DATASOURCE_NAME=settlement_ds_dev
PROTO_DESCRIPTOR_PATH=s3://bucket/schemas/settlement_transaction.desc
PROTO_MESSAGE_TYPE=com.company.SettlementTransactionEvent
TIMESTAMP_COLUMN=settlementTimestampMs
# ... autres configs
```

```bash
# config/payment-dev.env
KAFKA_TOPIC=payment-transactions-dev
DATASOURCE_NAME=payment_ds_dev
PROTO_DESCRIPTOR_PATH=s3://bucket/schemas/payment_transaction.desc
PROTO_MESSAGE_TYPE=com.company.PaymentTransactionEvent
TIMESTAMP_COLUMN=paymentTimestampMs
# ... autres configs
```

Puis utilisez avec `-d` :

```bash
# Build spec pour settlement
java -jar druid-ingestion.jar build -e dev -d settlement

# Deploy settlement
java -jar druid-ingestion.jar deploy -e dev -d settlement

# Build spec pour payment
java -jar druid-ingestion.jar build -e dev -d payment

# Deploy payment
java -jar druid-ingestion.jar deploy -e dev -d payment
```

### Option 2: Override via paramètre

Utilisez la config par défaut et override le datasource :

```bash
# Utilise dev.env mais avec datasource "settlement"
java -jar druid-ingestion.jar build -e dev -d settlement
```

## 📊 Exemples complets

### Exemple 1: Settlement Transactions

```bash
# 1. Créer config
cat > config/settlement-dev.env <<EOF
KAFKA_BOOTSTRAP_SERVERS=kafka-dev:9092
KAFKA_TOPIC=settlement-transactions-dev
DATASOURCE_NAME=settlement_ds_dev
PROTO_DESCRIPTOR_PATH=s3://schemas/settlement_transaction.desc
PROTO_MESSAGE_TYPE=com.company.SettlementTransactionEvent
DRUID_OVERLORD_URL=http://druid-dev:8888
TIMESTAMP_COLUMN=settlementTimestampMs
TIMESTAMP_FORMAT=millis
EOF

# 2. Créer schema spécifique (optionnel)
cat > config/schema-settlement.yml <<EOF
dimensions:
  - type: string
    name: uetr
  - type: string
    name: currency
metrics:
  - type: count
    name: count
  - type: doubleSum
    name: amount_sum
    fieldName: amount
EOF

# 3. Build et deploy
java -jar druid-ingestion.jar build -e dev -d settlement
java -jar druid-ingestion.jar deploy -e dev -d settlement
```

### Exemple 2: Payment Transactions

```bash
# 1. Créer config
cat > config/payment-dev.env <<EOF
KAFKA_BOOTSTRAP_SERVERS=kafka-dev:9092
KAFKA_TOPIC=payment-transactions-dev
DATASOURCE_NAME=payment_ds_dev
PROTO_DESCRIPTOR_PATH=s3://schemas/payment_transaction.desc
PROTO_MESSAGE_TYPE=com.company.PaymentTransactionEvent
DRUID_OVERLORD_URL=http://druid-dev:8888
TIMESTAMP_COLUMN=paymentTimestampMs
TIMESTAMP_FORMAT=millis
EOF

# 2. Build et deploy
java -jar druid-ingestion.jar build -e dev -d payment
java -jar druid-ingestion.jar deploy -e dev -d payment
```

## 🚀 GitLab CI avec multi-datasources

### Pipeline avec plusieurs datasources

```yaml
# .gitlab-ci.yml
deploy:settlement:dev:
  stage: deploy
  script:
    - java -jar druid-ingestion.jar build -e dev -d settlement
    - java -jar druid-ingestion.jar deploy -e dev -d settlement
  only:
    - develop

deploy:payment:dev:
  stage: deploy
  script:
    - java -jar druid-ingestion.jar build -e dev -d payment
    - java -jar druid-ingestion.jar deploy -e dev -d payment
  only:
    - develop
```

### Variables GitLab par datasource

Pour chaque datasource, configurez les variables :

```
# Settlement
KAFKA_TOPIC_SETTLEMENT_DEV=settlement-transactions-dev
DATASOURCE_NAME_SETTLEMENT_DEV=settlement_ds_dev
PROTO_DESCRIPTOR_PATH_SETTLEMENT_DEV=s3://bucket/schemas/settlement_transaction.desc

# Payment
KAFKA_TOPIC_PAYMENT_DEV=payment-transactions-dev
DATASOURCE_NAME_PAYMENT_DEV=payment_ds_dev
PROTO_DESCRIPTOR_PATH_PAYMENT_DEV=s3://bucket/schemas/payment_transaction.desc
```

## 📝 Bonnes pratiques

### 1. Nommage cohérent

Utilisez un nommage cohérent :
- Datasource : `{type}_ds_{env}` (ex: `settlement_ds_dev`)
- Topic : `{type}-transactions-{env}` (ex: `settlement-transactions-dev`)
- Config : `{type}-{env}.env` (ex: `settlement-dev.env`)
- Schema : `schema-{type}.yml` (ex: `schema-settlement.yml`)

### 2. Isolation des configs

Gardez les configs séparées :
- Un fichier `.env` par datasource
- Un fichier `schema.yml` par datasource (si différent)
- Pas de mélange entre datasources

### 3. Réutilisation

Pour les datasources similaires :
- Utilisez `schema.yml` par défaut
- Override seulement les différences dans `schema-{datasource}.yml`

### 4. Documentation

Documentez chaque datasource :
- Quel proto il utilise
- Quel topic Kafka
- Quelles dimensions/metrics spécifiques

## 🔍 Dépannage

### Erreur: "Config file not found"

Vérifiez que le fichier existe :
```bash
ls config/{datasource}-{env}.env
```

### Erreur: "Schema file not found"

L'application utilisera le schema par défaut. Créez un schema spécifique si nécessaire :
```bash
cp config/schema.yml config/schema-{datasource}.yml
# Éditez selon vos besoins
```

### Erreur: "Datasource name mismatch"

Assurez-vous que `DATASOURCE_NAME` dans le fichier de config correspond au paramètre `-d` :
```bash
# Dans settlement-dev.env
DATASOURCE_NAME=settlement_ds_dev

# Commande
java -jar druid-ingestion.jar deploy -e dev -d settlement_ds_dev
```

## 📚 Références

- [README.md](../README.md) - Documentation principale
- [GITLAB_CI.md](GITLAB_CI.md) - Configuration GitLab CI

