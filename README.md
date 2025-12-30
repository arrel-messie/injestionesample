# Druid Kafka Ingestion avec Protobuf et S3

Ce projet fournit une solution complète pour l'ingestion de données Kafka vers Apache Druid en utilisant des schémas Protobuf stockés sur S3, avec un pipeline CI/CD GitLab automatisé.

## 🏗️ Architecture

```
Kafka Topic (Protobuf) 
    ↓
Druid Superviseur 
    ↓ (lit le schema depuis)
S3 Bucket (descriptors .desc)
    ↓ (versionné via)
GitLab CI/CD Pipeline
```

## 📁 Structure du projet

```
druid-kafka-ingestion/
├── .gitlab-ci.yml              # Pipeline CI/CD
├── schemas/
│   └── proto/
│       └── settlement_transaction.proto  # Schéma Protobuf source
├── druid-specs/
│   └── templates/
│       └── kafka-supervisor.json         # Template avec envsubst
├── config/
│   ├── dimensions.json          # Définition des dimensions Druid (JSON)
│   ├── dev.env                  # Variables d'environnement dev
│   ├── staging.env              # Variables d'environnement staging
│   └── prod.env                 # Variables d'environnement prod
├── scripts/
│   ├── compile-proto.sh         # Script de compilation des .proto
│   ├── deploy-supervisor.sh     # Script de déploiement
│   └── rollback-schema.sh       # Script de rollback
└── docs/
    ├── SETUP.md                 # Guide d'installation
    └── DEPLOYMENT.md            # Guide de déploiement
```

## ✨ Points forts de cette solution

✅ **Zero dépendance externe** - Utilise uniquement des outils natifs Linux
- `envsubst` (pré-installé, package gettext-base)
- `jq` (standard DevOps, ~3MB)
- `curl` (déjà présent partout)

✅ **Standard de l'industrie** - Approche utilisée par Kubernetes, Docker, Nginx

✅ **Simple et maintenable** - Pas de "magie", syntaxe claire

✅ **Performant** - Très rapide, images Docker légères

## 🚀 Démarrage rapide

### Prérequis

- Accès GitLab avec CI/CD activé
- Bucket S3 configuré (ex: `my-company-druid-schemas`)
- Credentials AWS configurés dans GitLab CI/CD
- Cluster Druid avec accès S3
- Cluster Kafka avec authentification SASL_SSL

### Configuration initiale

1. **Configurer les variables GitLab CI/CD**
   
   Dans `Settings > CI/CD > Variables`, ajouter :
   - `AWS_ACCESS_KEY_ID` - Accès S3
   - `AWS_SECRET_ACCESS_KEY` - Secret S3
   - `KAFKA_PROD_USER` - Username Kafka production
   - `KAFKA_PROD_PASSWORD` - Password Kafka production
   - `S3_BUCKET` - Nom du bucket (ex: `my-company-druid-schemas`)
   - `S3_REGION` - Région AWS (ex: `eu-west-1`)

2. **Adapter les fichiers de configuration**
   
   Modifier les fichiers dans `config/` selon vos environnements

3. **Définir votre schéma Protobuf**
   
   Éditer `schemas/proto/settlement_transaction.proto`

4. **Définir vos dimensions Druid**
   
   Éditer `config/dimensions.json`

### Déploiement

1. **Push vers develop** → Déploie automatiquement en DEV
2. **Push vers staging** → Déploie automatiquement en STAGING
3. **Push vers main/master** → Déploie manuellement en PROD

## 🔄 Template envsubst

Le projet utilise `envsubst` pour la substitution de variables :

```json
{
  "topic": "${KAFKA_TOPIC}",
  "taskCount": ${TASK_COUNT:-10}
}
```

**Syntaxe :**
- `${VAR}` - Variable obligatoire
- `${VAR:-default}` - Variable avec valeur par défaut

## 📊 Versioning des schémas

Chaque commit génère une version de schéma :
- `s3://bucket/schemas/{COMMIT_SHA}/` - Version spécifique
- `s3://bucket/schemas/develop-latest/` - Dernière version develop
- `s3://bucket/schemas/stable/` - Version stable (main/master)

## 🔧 Configuration Druid

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

## 🛠️ Commandes utiles

### Déploiement
```bash
make deploy-dev      # Déployer en DEV
make deploy-staging  # Déployer en STAGING
make deploy-prod     # Déployer en PRODUCTION
```

### Validation
```bash
make validate        # Valider la configuration
make compile         # Compiler les .proto
```

### Monitoring
```bash
make status ENV=dev  # Statut du superviseur
make logs ENV=dev    # Logs du superviseur
```

### Rollback
```bash
make rollback ENV=prod VERSION=abc123f
```

### Compilation manuelle
```bash
./scripts/compile-proto.sh
```

### Test local
```bash
source config/dev.env
export DIMENSIONS_JSON=$(cat config/dimensions.json | jq -c .)
envsubst < druid-specs/templates/kafka-supervisor.json > test-output.json
jq . test-output.json  # Vérifier le JSON
```

## 📖 Documentation

- [Guide d'installation détaillé](docs/SETUP.md)
- [Guide de déploiement](docs/DEPLOYMENT.md)
- [Démarrage rapide 5 minutes](QUICKSTART.md)

## 🔒 Sécurité

- Les credentials sont stockés dans GitLab CI/CD Variables (masqués)
- Descriptors S3 accessibles en lecture seule par Druid
- SASL_SSL activé pour Kafka

## 🐛 Troubleshooting

### Le superviseur ne démarre pas
1. Vérifier le descriptor sur S3
2. Vérifier les permissions IAM
3. Consulter les logs Druid

### Erreurs de parsing Protobuf
1. Vérifier `protoMessageType`
2. Vérifier compilation avec `--include_imports`

### JSON invalide
```bash
jq empty supervisor-spec.json  # Valider
```

## 📝 License

Propriétaire - Usage interne uniquement

## 👥 Contributeurs

Votre équipe Data Engineering
