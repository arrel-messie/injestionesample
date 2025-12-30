# 🚀 Démarrage Rapide - 5 minutes

Ce guide vous permet de démarrer rapidement avec le projet d'ingestion Druid.

## Étape 1 : Extraction (30 secondes)

```bash
unzip druid-kafka-ingestion.zip
cd druid-kafka-ingestion
```

## Étape 2 : Vérifier les dépendances (30 secondes)

```bash
make check-deps
```

**Dépendances requises** (déjà présentes sur la plupart des systèmes Linux) :
- `envsubst` (gettext-base) - ✅ Pré-installé
- `jq` (~3MB) - Installation : `apt-get install jq`
- `protoc` - Installation : `apt-get install protobuf-compiler`
- `curl` - ✅ Pré-installé

**Installation rapide Ubuntu/Debian :**
```bash
make install-deps-ubuntu
```

**Installation rapide macOS :**
```bash
make install-deps-macos
```

## Étape 3 : Configuration GitLab (2 minutes)

1. **Créer un nouveau projet GitLab** et push le code

2. **Configurer les variables CI/CD**
   
   Dans `Settings > CI/CD > Variables` :
   
   | Variable | Valeur | Masked |
   |----------|--------|--------|
   | `AWS_ACCESS_KEY_ID` | `AKIA...` | Non |
   | `AWS_SECRET_ACCESS_KEY` | `secret...` | Oui ✓ |
   | `S3_BUCKET` | `my-company-druid-schemas` | Non |
   | `S3_REGION` | `eu-west-1` | Non |
   | `KAFKA_PROD_USER` | `prod-user` | Non |
   | `KAFKA_PROD_PASSWORD` | `prod-pass` | Oui ✓ |

3. **Créer les branches**
   ```bash
   git checkout -b develop
   git push origin develop
   git checkout -b staging
   git push origin staging
   ```

## Étape 4 : Adapter les configurations (2 minutes)

### 1. Modifier `config/dev.env`
```bash
vim config/dev.env

# Adapter ces valeurs :
KAFKA_BOOTSTRAP_SERVERS="votre-kafka:9092"
DRUID_OVERLORD_URL="http://votre-druid:8090"
PROTO_MESSAGE_TYPE="votre.package.MessageType"
```

### 2. Modifier `schemas/proto/settlement_transaction.proto`
Adapter selon votre structure de données

### 3. Modifier `config/dimensions.json`
Définir vos dimensions Druid en JSON

## Étape 5 : Premier déploiement (30 secondes)

```bash
# Commit et push vers develop
git add config/ schemas/
git commit -m "Configure for our environment"
git push origin develop

# Le pipeline GitLab CI/CD va automatiquement :
# ✅ Compiler le .proto en .desc
# ✅ Uploader vers S3
# ✅ Déployer en DEV
```

## Étape 6 : Vérification (30 secondes)

**Vérifier le pipeline GitLab :**
- Aller dans CI/CD > Pipelines
- Tous les jobs doivent être verts ✅

**Vérifier le superviseur Druid :**
```bash
make status ENV=dev
```

Ou via la console : `http://votre-druid:8090/unified-console.html#supervisors`

## 🛠️ Commandes essentielles

```bash
# Déploiement
make deploy-dev          # Déployer en DEV
make deploy-staging      # Déployer en STAGING
make deploy-prod         # Déployer en PRODUCTION

# Validation
make validate            # Valider les configs
make compile             # Compiler les .proto
make test-template ENV=dev  # Tester la génération

# Monitoring
make status ENV=dev      # Statut du superviseur
make logs ENV=dev        # Logs du superviseur

# Rollback
make rollback ENV=prod VERSION=abc123f
```

## 🔧 Test local avant GitLab

```bash
# Compiler localement
make compile

# Tester la génération du template
make test-template ENV=dev

# Valider le JSON
make validate
```

## 📋 Syntaxe envsubst (utilisée dans les templates)

Le projet utilise `envsubst` pour substituer les variables :

```json
{
  "topic": "${KAFKA_TOPIC}",
  "taskCount": ${TASK_COUNT:-10}
}
```

**Syntaxe :**
- `${VAR}` - Variable obligatoire
- `${VAR:-default}` - Variable avec valeur par défaut

## 🐛 Troubleshooting rapide

### envsubst non trouvé
```bash
sudo apt-get install gettext-base
```

### jq non trouvé
```bash
sudo apt-get install jq
```

### Le superviseur ne démarre pas
```bash
# Vérifier les logs
make logs ENV=dev

# Vérifier le schéma sur S3
make list-schemas
```

### JSON invalide
```bash
# Tester localement
make test-template ENV=dev
jq . test-output.json
```

## 📖 Documentation complète

- **README.md** - Vue d'ensemble
- **docs/SETUP.md** - Installation détaillée
- **docs/DEPLOYMENT.md** - Procédures de déploiement

## ✨ Avantages de cette solution

✅ **Zero dépendance externe** - Outils natifs Linux uniquement  
✅ **Standard de l'industrie** - envsubst utilisé par Kubernetes, Docker  
✅ **Simple et rapide** - Pas de "magie", syntaxe claire  
✅ **Performant** - Très rapide, images Docker légères  

---

**Prêt à déployer ? Lancez-vous !** 🚀
