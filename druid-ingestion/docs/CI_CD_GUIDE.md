# Guide CI/CD Professionnel

## 🎯 Objectif

Solution professionnelle pour déployer automatiquement :
1. **Génération de la spec** d'ingestion Druid
2. **Déploiement de la spec** sur un serveur Druid distant
3. **Upload du fichier .desc** sur un stockage distant (S3)
4. **Tout via GitLab CI/CD**

## 📋 Architecture

```
GitLab CI Pipeline
├── Stage: build
│   └── Job: build
│       ├── Compile protobuf (.desc)
│       └── Generate specs (JSON)
│
└── Stage: deploy
    ├── Job: deploy:dev (manuel)
    ├── Job: deploy:staging (manuel)
    └── Job: deploy:prod (manuel)
        ├── Upload .desc → S3
        └── Deploy spec → Druid
```

## 🚀 Utilisation

### 1. Configuration GitLab

Dans **Settings → CI/CD → Variables**, ajouter :

**Variables communes :**
- `PROTO_MESSAGE_TYPE` = `com.company.PaymentTransactionEvent`
- `AWS_ACCESS_KEY_ID` = `AKIA...` (masquée)
- `AWS_SECRET_ACCESS_KEY` = `...` (masquée)

**Variables DEV :**
- `KAFKA_BOOTSTRAP_SERVERS_DEV` = `kafka-dev:9092`
- `KAFKA_TOPIC_DEV` = `settlement-transactions-dev`
- `DRUID_OVERLORD_URL_DEV` = `http://druid-dev:8090`
- `DATASOURCE_NAME_DEV` = `idm_settlement_snapshot_dev`
- `S3_BUCKET_DEV` = `druid-schemas-dev`
- `PROTO_DESCRIPTOR_PATH_DEV` = `s3://druid-schemas-dev/schemas/settlement_transaction.desc`

**Variables STAGING/PROD :** (même structure avec _STAGING/_PROD)

### 2. Workflow

```bash
# 1. Push sur feature branch
git push origin feature/my-feature

# 2. Merge request → build automatique
#    - Compile .desc
#    - Génère specs

# 3. Merge dans develop → build automatique

# 4. Déploiement manuel DEV
#    - GitLab CI/CD → Pipelines → Play ▶️ deploy:dev
#    - Upload .desc → S3
#    - Deploy spec → Druid

# 5. Merge dans main → build automatique

# 6. Déploiement manuel PROD
#    - GitLab CI/CD → Pipelines → Play ▶️ deploy:prod
```

## 🔧 Commandes Locales (pour test)

```bash
# Compiler le protobuf
./druid-ingestion.sh compile-proto

# Générer la spec
./druid-ingestion.sh build -e dev

# Déployer (nécessite config)
./druid-ingestion.sh deploy -e dev

# Vérifier le statut
./druid-ingestion.sh status -e dev
```

## 📦 Fichiers Générés

### Build Stage
- `schemas/compiled/settlement_transaction.desc` → Artifact
- `druid-specs/generated/supervisor-spec-*-dev.json` → Artifact

### Deploy Stage
- Upload `.desc` → `s3://bucket/schemas/settlement_transaction.desc`
- Deploy `.json` → `http://druid-overlord/druid/indexer/v1/supervisor`

## ✅ Avantages de cette approche

1. **Automatisation** : Build automatique sur chaque push
2. **Sécurité** : Déploiements manuels pour éviter les erreurs
3. **Traçabilité** : Tous les déploiements tracés dans GitLab
4. **Reproductibilité** : Même processus pour tous les environnements
5. **Simplicité** : Un seul script, une seule pipeline

## 🔒 Sécurité

- Variables masquées dans GitLab
- Déploiements manuels uniquement
- Credentials AWS via variables GitLab
- Pas de secrets dans le code

## 🐛 Troubleshooting

### Build échoue
- Vérifier que `protoc` est installé dans l'image
- Vérifier les chemins des fichiers proto

### Deploy échoue
- Vérifier les variables d'environnement
- Vérifier la connectivité au Druid Overlord
- Vérifier les credentials AWS pour S3

### Spec invalide
- Vérifier `config/schema.yml`
- Vérifier `config/defaults.yml`
- Tester localement avec `./druid-ingestion.sh build -e dev`
