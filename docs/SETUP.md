# Guide d'installation

Installation complète du projet d'ingestion Druid.

## Prérequis système

### Outils requis (tous natifs Linux)

- **envsubst** - Substitution de variables (pré-installé, package gettext-base)
- **jq** - Parser JSON (~3MB)
- **protoc** - Compilateur Protobuf
- **curl** - Client HTTP (pré-installé)
- **aws-cli** - Pour S3 (optionnel, seulement pour rollback manuel)

### Installation Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install -y gettext-base jq protobuf-compiler curl
pip3 install awscli  # Optionnel
```

### Installation macOS
```bash
brew install gettext jq protobuf curl
pip3 install awscli  # Optionnel
```

### Vérification
```bash
make check-deps
```

## Configuration GitLab

### 1. Variables CI/CD

Dans GitLab `Settings > CI/CD > Variables`, ajouter :

**Obligatoires :**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `S3_BUCKET`
- `S3_REGION`
- `KAFKA_PROD_USER`
- `KAFKA_PROD_PASSWORD`

Voir `gitlab-ci-variables-example.txt` pour les détails.

### 2. Branches protégées

Protéger les branches : `main`, `staging`, `develop`

## Configuration S3

### Créer le bucket
```bash
aws s3 mb s3://my-company-druid-schemas --region eu-west-1
```

### Politique IAM pour Druid (lecture seule)
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::my-company-druid-schemas",
      "arn:aws:s3:::my-company-druid-schemas/schemas/*"
    ]
  }]
}
```

### Politique IAM pour GitLab CI (lecture/écriture)
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:PutObject", "s3:DeleteObject", "s3:GetObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::my-company-druid-schemas",
      "arn:aws:s3:::my-company-druid-schemas/schemas/*"
    ]
  }]
}
```

## Configuration Druid

### Extensions requises
```properties
druid.extensions.loadList=["druid-s3-extensions", "druid-protobuf-extensions", "druid-kafka-indexing-service"]
```

### Configuration S3
```properties
druid.storage.type=s3
druid.storage.bucket=my-company-druid-segments
druid.s3.accessKey=${AWS_ACCESS_KEY_ID}
druid.s3.secretKey=${AWS_SECRET_ACCESS_KEY}
```

## Adapter le projet

### 1. Modifier les configurations
```bash
vim config/dev.env
vim config/staging.env
vim config/prod.env
```

Adapter :
- `KAFKA_BOOTSTRAP_SERVERS`
- `DRUID_OVERLORD_URL`
- `PROTO_MESSAGE_TYPE`
- `DATASOURCE_NAME`

### 2. Modifier le schéma Protobuf
```bash
vim schemas/proto/settlement_transaction.proto
```

### 3. Modifier les dimensions
```bash
vim config/dimensions.json
```

Format :
```json
[
  {"type": "string", "name": "field1"},
  {"type": "long", "name": "field2"}
]
```

## Premier déploiement

### Test local
```bash
# Compiler
make compile

# Tester la génération
make test-template ENV=dev

# Valider
make validate
```

### Déploiement via GitLab
```bash
git checkout develop
git add .
git commit -m "Initial configuration"
git push origin develop

# Le pipeline déploie automatiquement en DEV
```

### Vérification
```bash
# Statut
make status ENV=dev

# Logs
make logs ENV=dev

# Console Druid
open http://druid-overlord-dev:8090/unified-console.html#supervisors
```

## Troubleshooting

### Problème : JSON invalide
```bash
# Tester localement
make test-template ENV=dev
jq . test-output.json
```

### Problème : envsubst non trouvé
```bash
sudo apt-get install gettext-base
```

### Problème : Superviseur ne démarre pas
1. Vérifier les logs Druid
2. Vérifier le descriptor sur S3
3. Vérifier les permissions IAM

## Documentation complète

- [README.md](../README.md) - Vue d'ensemble
- [QUICKSTART.md](../QUICKSTART.md) - Démarrage rapide
- [DEPLOYMENT.md](DEPLOYMENT.md) - Procédures de déploiement
