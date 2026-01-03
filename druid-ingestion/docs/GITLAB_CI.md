# GitLab CI/CD Configuration

Guide professionnel pour déployer automatiquement les supervisors Druid et uploader les descripteurs Protobuf sur S3 via GitLab CI.

## 📋 Vue d'ensemble

Le pipeline GitLab CI comprend deux stages :

1. **build** : Compile le protobuf et génère les specs pour tous les environnements
2. **deploy** : Upload le descripteur sur S3 et déploie le supervisor Druid (manuel pour sécurité)

## 🔧 Configuration requise

### Variables GitLab CI/CD

Configurez les variables suivantes dans GitLab (Settings → CI/CD → Variables) :

#### Variables communes

- `PROTO_MESSAGE_TYPE` : Type de message Protobuf (ex: `com.company.PaymentTransactionEvent`)
- `AWS_ACCESS_KEY_ID` : Clé d'accès AWS (pour S3)
- `AWS_SECRET_ACCESS_KEY` : Clé secrète AWS (pour S3)

#### Variables par environnement (dev/staging/prod)

**Kafka:**
- `KAFKA_BOOTSTRAP_SERVERS_{ENV}` : Serveurs Kafka
- `KAFKA_SECURITY_PROTOCOL_{ENV}` : Protocole de sécurité (PLAINTEXT, SASL_SSL, etc.)
- `KAFKA_SASL_MECHANISM_{ENV}` : Mécanisme SASL (PLAIN, SCRAM-SHA-256, etc.)
- `KAFKA_SASL_JAAS_CONFIG_{ENV}` : Configuration JAAS (masquée)
- `KAFKA_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM_{ENV}` : Algorithme SSL (optionnel)
- `KAFKA_TOPIC_{ENV}` : Topic Kafka

**S3:**
- `S3_BUCKET_{ENV}` : Nom du bucket S3
- `S3_REGION_{ENV}` : Région AWS (défaut: `us-east-1`)

**Druid:**
- `DRUID_OVERLORD_URL_{ENV}` : URL du Druid Overlord
- `DATASOURCE_NAME_{ENV}` : Nom de la datasource
- `PROTO_DESCRIPTOR_PATH_{ENV}` : Chemin S3 du descripteur (ex: `s3://bucket/schemas/settlement_transaction.desc`)

### Exemple de configuration

Pour l'environnement `dev` :

```
KAFKA_BOOTSTRAP_SERVERS_DEV=kafka-dev.example.com:9092
KAFKA_SECURITY_PROTOCOL_DEV=SASL_SSL
KAFKA_SASL_MECHANISM_DEV=PLAIN
KAFKA_SASL_JAAS_CONFIG_DEV=org.apache.kafka.common.security.plain.PlainLoginModule required username="user" password="pass";
KAFKA_TOPIC_DEV=settlement-transactions-dev
S3_BUCKET_DEV=druid-schemas-dev
S3_REGION_DEV=us-east-1
DRUID_OVERLORD_URL_DEV=http://druid-overlord-dev:8090
DATASOURCE_NAME_DEV=idm_settlement_snapshot_dev
PROTO_DESCRIPTOR_PATH_DEV=s3://druid-schemas-dev/schemas/settlement_transaction.desc
```

## 🚀 Utilisation

### Déclenchement automatique

Le stage `build` s'exécute automatiquement sur :
- Push sur `main` ou `develop`
- Création de merge requests

### Déploiement manuel

Les stages `deploy` sont **manuels** pour la sécurité :

1. Aller dans GitLab CI/CD → Pipelines
2. Sélectionner le pipeline souhaité
3. Cliquer sur le bouton "Play" (▶️) du job `deploy:dev`, `deploy:staging`, ou `deploy:prod`

### Workflow recommandé

```
1. Développement sur feature branch
   ↓
2. Merge request → build automatique
   ↓
3. Merge dans develop → build automatique
   ↓
4. Déploiement manuel sur dev (test)
   ↓
5. Merge dans main → build automatique
   ↓
6. Déploiement manuel sur staging (validation)
   ↓
7. Déploiement manuel sur prod (production)
```

## 📦 Artifacts

Le stage `build` génère des artifacts :
- `schemas/compiled/*.desc` : Descripteurs Protobuf compilés
- `druid-specs/generated/*.json` : Specs Druid générées

Ces artifacts sont disponibles pour téléchargement et sont utilisés par les stages `deploy`.

## 🔒 Sécurité

### Variables masquées

Les variables sensibles (mots de passe, clés) doivent être :
- **Masquées** dans GitLab (Settings → CI/CD → Variables → Mask variable)
- **Protégées** (Settings → CI/CD → Variables → Protect variable) pour limiter aux branches protégées

### Déploiements manuels

Les déploiements sont manuels pour :
- Éviter les déploiements accidentels
- Permettre la validation avant déploiement
- Respecter les processus d'approbation

## 🐛 Debugging

### Voir les logs

```bash
# Dans GitLab CI/CD → Pipelines → Job
# Les logs montrent :
# - Compilation du protobuf
# - Génération des specs
# - Upload S3
# - Déploiement Druid
```

### Tester localement

```bash
# Simuler le build
docker run --rm -v $(pwd):/workspace -w /workspace alpine:latest sh -c "
  apk add --no-cache bash curl jq yq python3 py3-pip protobuf
  pip3 install pyyaml
  chmod +x druid-ingestion.sh
  protoc --descriptor_set_out=schemas/compiled/settlement_transaction.desc \
    --proto_path=schemas/proto schemas/proto/settlement_transaction.proto
  ./druid-ingestion.sh build -e dev
"
```

## 📝 Checklist avant déploiement

- [ ] Variables GitLab CI configurées pour l'environnement
- [ ] Credentials AWS configurés (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
- [ ] Bucket S3 existe et est accessible
- [ ] Druid Overlord est accessible depuis le runner
- [ ] Spec générée et validée (vérifier dans artifacts)
- [ ] Descripteur compilé correctement (vérifier dans artifacts)

## 🔄 Rollback

En cas de problème, vous pouvez :

1. **Rollback manuel** : Utiliser une version précédente de la spec
2. **Re-déployer** : Relancer le job de déploiement avec une version antérieure
3. **Arrêter le supervisor** : Via l'interface Druid ou API

```bash
# Arrêter un supervisor via API
curl -X POST "${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor/${DATASOURCE}/shutdown"
```

