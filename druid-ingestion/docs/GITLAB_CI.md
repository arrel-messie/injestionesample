# GitLab CI/CD Configuration

Ce document décrit la configuration GitLab CI pour déployer automatiquement les supervisors Druid et uploader les descripteurs Protobuf sur S3.

## 📋 Vue d'ensemble

Le pipeline GitLab CI comprend deux stages :

1. **build** : Compile le projet Java et génère le descripteur Protobuf
2. **deploy** : Upload le descripteur sur S3 et déploie le supervisor Druid

## 🔧 Configuration requise

### Variables GitLab CI/CD

Configurez les variables suivantes dans GitLab (Settings → CI/CD → Variables) :

#### Variables communes
- `PROTO_MESSAGE_TYPE` : Type de message Protobuf (ex: `com.company.PaymentTransactionEvent`)

#### Variables par environnement (dev/staging/prod)

**Kafka:**
- `KAFKA_BOOTSTRAP_SERVERS_{ENV}` : Serveurs Kafka
- `KAFKA_SECURITY_PROTOCOL_{ENV}` : Protocole de sécurité
- `KAFKA_SASL_MECHANISM_{ENV}` : Mécanisme SASL
- `KAFKA_SASL_JAAS_CONFIG_{ENV}` : Configuration JAAS
- `KAFKA_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM_{ENV}` : Algorithme SSL
- `KAFKA_TOPIC_{ENV}` : Topic Kafka
- `KAFKA_AUTO_OFFSET_RESET_{ENV}` : Reset offset

**S3:**
- `S3_BUCKET_{ENV}` : Nom du bucket S3
- `S3_ENDPOINT_{ENV}` : Endpoint S3 (optionnel, pour MinIO)
- `S3_REGION_{ENV}` : Région AWS (défaut: `us-east-1`)
- `AWS_ACCESS_KEY_ID` : Clé d'accès AWS (utilisée par AWS CLI)
- `AWS_SECRET_ACCESS_KEY` : Clé secrète AWS (utilisée par AWS CLI)

**Druid:**
- `DRUID_OVERLORD_URL_{ENV}` : URL du Druid Overlord
- `DATASOURCE_NAME_{ENV}` : Nom de la datasource
- `TIMESTAMP_COLUMN_{ENV}` : Colonne timestamp (ex: `settlementTimestampMs`)
- `TIMESTAMP_FORMAT_{ENV}` : Format timestamp (ex: `millis`)

### Exemple de configuration

Pour l'environnement `dev` :

```
KAFKA_BOOTSTRAP_SERVERS_DEV=kafka-dev.example.com:9092
KAFKA_SECURITY_PROTOCOL_DEV=SASL_SSL
KAFKA_SASL_MECHANISM_DEV=PLAIN
KAFKA_SASL_JAAS_CONFIG_DEV=org.apache.kafka.common.security.plain.PlainLoginModule required username="user" password="pass";
KAFKA_TOPIC_DEV=settlement-transactions-dev
S3_BUCKET_DEV=druid-schemas-dev
S3_ENDPOINT_DEV=https://s3.amazonaws.com
S3_REGION_DEV=us-east-1
DRUID_OVERLORD_URL_DEV=https://druid-overlord-dev.example.com:8888
DATASOURCE_NAME_DEV=idm_settlement_snapshot_dev
TIMESTAMP_COLUMN_DEV=settlementTimestampMs
TIMESTAMP_FORMAT_DEV=millis
```

## 🚀 Pipeline

### Stage: build

- **Image** : `maven:3.9-eclipse-temurin-21`
- **Actions** :
  1. Installe `protoc` (Protobuf compiler)
  2. Compile le projet Java avec Maven
  3. Génère le descripteur Protobuf (`.desc`)
- **Artifacts** : JAR exécutable et descripteur Protobuf

### Stage: deploy

Jobs disponibles :
- `deploy:dev` : Déploiement en développement (branche `develop`)
- `deploy:staging` : Déploiement en staging (branche `main`)
- `deploy:prod` : Déploiement en production (tags uniquement)

Chaque job :
1. **Upload S3** : Upload le descripteur Protobuf sur S3
2. **Build spec** : Génère le JSON de spec Druid
3. **Deploy** : Déploie le supervisor sur Druid

## 📝 Utilisation

### Déploiement manuel

Les jobs de déploiement sont **manuels** par défaut pour la sécurité :

1. Aller dans GitLab CI/CD → Pipelines
2. Cliquer sur le pipeline souhaité
3. Cliquer sur le bouton "Play" (▶️) du job `deploy:{env}`

### Déploiement automatique

Pour activer le déploiement automatique, modifiez `.gitlab-ci.yml` :

```yaml
deploy:dev:
  # ... autres configs ...
  when: on_success  # Au lieu de 'manual'
```

### Déploiement conditionnel

Le déploiement en production nécessite un **tag Git** :

```bash
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0
```

## 🔍 Dépannage

### Erreur: "Descriptor file not found"

Vérifiez que le stage `build` a bien généré le descripteur :
- Regardez les artifacts du job `build`
- Vérifiez que `schemas/compiled/settlement_transaction.desc` existe

### Erreur: "S3 upload failed"

Vérifiez :
- Les variables `S3_BUCKET_{ENV}`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- Les permissions IAM pour l'accès S3
- L'endpoint S3 (si MinIO ou S3-compatible)

### Erreur: "Druid deployment failed"

Vérifiez :
- `DRUID_OVERLORD_URL_{ENV}` est accessible depuis GitLab Runner
- Les credentials Druid (si authentification requise)
- Le fichier de config `{env}.env` est correct

## 🔐 Sécurité

### Variables sensibles

Marquez les variables sensibles comme **masked** et **protected** dans GitLab :
- `KAFKA_SASL_JAAS_CONFIG_{ENV}`
- `AWS_SECRET_ACCESS_KEY`
- Toutes les clés d'accès

### Protection des branches

- `deploy:prod` ne s'exécute que sur les tags
- Tous les déploiements sont manuels par défaut
- Utilisez des runners dédiés pour la production

## 📚 Références

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [AWS CLI Documentation](https://awscli.amazonaws.com/v2/documentation/)
- [Druid Ingestion Documentation](../README.md)

