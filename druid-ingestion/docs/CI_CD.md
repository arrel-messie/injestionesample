# CI/CD Pipeline Guide

Guide complet pour configurer et utiliser le pipeline GitLab CI/CD.

## Configuration

### Variables GitLab CI requises

#### Variables communes
- `PROTO_MESSAGE_TYPE`: Type de message Protobuf (ex: `com.company.PaymentTransactionEvent`)
- `PROTO_FILE`: Chemin vers le fichier proto (ex: `schemas/proto/settlement_transaction.proto`)

#### Variables par environnement (DEV)
- `KAFKA_BOOTSTRAP_SERVERS_DEV`
- `KAFKA_SECURITY_PROTOCOL_DEV`
- `KAFKA_SASL_MECHANISM_DEV`
- `KAFKA_SASL_JAAS_CONFIG_DEV`
- `KAFKA_TOPIC_DEV`
- `DRUID_OVERLORD_URL_DEV`
- `DATASOURCE_NAME_DEV`
- `PROTO_DESCRIPTOR_PATH_DEV`
- `S3_BUCKET_DEV` (optionnel)
- `S3_REGION_DEV` (optionnel)

#### Variables par environnement (STAGING/PROD)
Même structure avec suffixe `_STAGING` ou `_PROD`.

### Configuration AWS (pour S3)

Si vous utilisez S3 pour stocker les descripteurs :
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Ou utilisez les credentials IAM du runner GitLab.

## Pipeline

### Stage: Build

1. **Compile Protobuf** : Génère le fichier `.desc`
2. **Génère les specs** : Crée les specs JSON pour tous les environnements

**Artifacts** :
- `schemas/compiled/*.desc`
- `druid-specs/generated/*.json`

### Stage: Deploy

Jobs manuels pour chaque environnement :
- `deploy:dev` : Déploiement en développement
- `deploy:staging` : Déploiement en staging
- `deploy:prod` : Déploiement en production

**Actions** :
1. Upload du descripteur `.desc` vers S3 (si configuré)
2. Déploiement du supervisor vers Druid

## Utilisation

### Déclencher un build

Le build se déclenche automatiquement sur :
- Push vers `main` ou `develop`
- Merge requests

### Déclencher un déploiement

1. Aller dans **CI/CD > Pipelines**
2. Sélectionner le pipeline
3. Cliquer sur **Play** sur le job `deploy:dev`, `deploy:staging` ou `deploy:prod`

## Troubleshooting

### Erreur: "protoc not found"
- Vérifier que l'image Docker inclut `protobuf` (déjà inclus dans `alpine:latest`)

### Erreur: "Config file not found"
- Vérifier que les variables GitLab CI sont bien configurées
- Vérifier que le fichier `.env` est généré dans `before_script`

### Erreur: "S3 upload failed"
- Vérifier les credentials AWS
- Vérifier les permissions du bucket S3
- Vérifier que `S3_BUCKET_*` est configuré

### Erreur: "HTTP 4xx/5xx"
- Vérifier que `DRUID_OVERLORD_URL_*` est correct
- Vérifier que le supervisor spec est valide
- Vérifier les logs Druid

