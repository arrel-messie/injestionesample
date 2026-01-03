# Guide de Test - Druid Ingestion Manager

## 🔍 Prérequis

### Outils requis
```bash
# Vérifier les outils installés
command -v bash && echo "✅ bash" || echo "❌ bash manquant"
command -v jq && echo "✅ jq" || echo "❌ jq manquant"
command -v curl && echo "✅ curl" || echo "❌ curl manquant"
command -v protoc && echo "✅ protoc" || echo "⚠️ protoc manquant (nécessaire pour compile-proto)"
command -v envsubst && echo "✅ envsubst" || echo "⚠️ envsubst manquant (nécessaire pour build)"
```

### Installation (macOS)
```bash
brew install jq curl protobuf
# envsubst est inclus dans gettext
brew install gettext
```

### Installation (Linux)
```bash
apt-get update && apt-get install -y jq curl protobuf-compiler gettext-base
# ou
yum install -y jq curl protobuf-compiler gettext
```

## 📋 Tests par Fonctionnalité

### 1. Test de l'aide (help)

```bash
cd druid-ingestion
./druid-ingestion.sh help
# ou
./druid-ingestion.sh --help
# ou
./druid-ingestion.sh -h
```

**Résultat attendu** : Affichage du message d'aide avec les commandes disponibles.

---

### 2. Test des prérequis

```bash
./druid-ingestion.sh build -e dev
```

**Résultat attendu** :
- Si outils manquants : Message d'erreur avec instructions d'installation
- Si outils présents : Passage à la suite

---

### 3. Test de compilation Protobuf

```bash
# Test avec valeurs par défaut
./druid-ingestion.sh compile-proto

# Test avec options personnalisées
./druid-ingestion.sh compile-proto \
  -f schemas/proto/settlement_transaction.proto \
  -o /tmp/test.desc
```

**Résultat attendu** :
- Fichier `.desc` généré dans `schemas/compiled/` (ou chemin spécifié)
- Message avec le chemin du fichier généré

**Vérification** :
```bash
ls -lh schemas/compiled/settlement_transaction.desc
file schemas/compiled/settlement_transaction.desc
# Devrait afficher: "Google Protocol Buffer"
```

---

### 4. Test de génération de spec (build)

#### 4.1 Test avec environnement dev

```bash
# Créer config/dev.env si nécessaire
cat > config/dev.env << EOF
KAFKA_BOOTSTRAP_SERVERS="localhost:9092"
KAFKA_SECURITY_PROTOCOL="PLAINTEXT"
KAFKA_TOPIC="settlement-transactions-dev"
DRUID_URL="http://localhost:8888"
DATASOURCE="idm_settlement_snapshot_dev"
PROTO_DESCRIPTOR_PATH="file:///opt/shared/schemas/settlement_transaction.desc"
PROTO_MESSAGE_TYPE="com.company.PaymentTransactionEvent"
EOF

# Générer la spec
./druid-ingestion.sh build -e dev
```

**Résultat attendu** :
- Fichier JSON généré dans `druid-specs/generated/supervisor-spec-{DATASOURCE}-dev.json`
- Message avec le chemin du fichier généré

**Vérification** :
```bash
# Vérifier que le fichier existe
ls -lh druid-specs/generated/supervisor-spec-*-dev.json

# Vérifier que c'est du JSON valide
jq empty druid-specs/generated/supervisor-spec-*-dev.json && echo "✅ JSON valide" || echo "❌ JSON invalide"

# Afficher le contenu (premières lignes)
jq . druid-specs/generated/supervisor-spec-*-dev.json | head -20
```

#### 4.2 Test avec output personnalisé

```bash
./druid-ingestion.sh build -e dev -o /tmp/test-spec.json
cat /tmp/test-spec.json | jq . | head -20
```

#### 4.3 Test avec différents environnements

```bash
# Dev
./druid-ingestion.sh build -e dev

# Staging (si config/staging.env existe)
./druid-ingestion.sh build -e staging

# Prod (si config/prod.env existe)
./druid-ingestion.sh build -e prod
```

---

### 5. Test de déploiement (deploy)

**⚠️ Nécessite un serveur Druid accessible**

```bash
# Déployer sur dev
./druid-ingestion.sh deploy -e dev
```

**Résultat attendu** :
- Si Druid accessible : Message de succès avec réponse JSON
- Si Druid inaccessible : Message d'erreur HTTP

**Vérification** :
```bash
# Vérifier le statut après déploiement
./druid-ingestion.sh status -e dev
```

---

### 6. Test de statut (status)

**⚠️ Nécessite un serveur Druid accessible**

```bash
./druid-ingestion.sh status -e dev
```

**Résultat attendu** :
- JSON avec le statut du supervisor
- Ou message d'erreur si supervisor n'existe pas

---

## 🧪 Tests de Validation

### Test 1: Validation des fonctions de logging

```bash
# Tester que les fonctions de logging fonctionnent
source lib/logger.sh
log_info "Test info"
log_warn "Test warning"
log_error "Test error"
```

**Résultat attendu** : Messages colorés affichés.

---

### Test 2: Validation du chargement de config

```bash
# Tester le chargement de config
source lib/config.sh
load_config dev config
echo "DATASOURCE: $DATASOURCE"
echo "KAFKA_TOPIC: $KAFKA_TOPIC"
```

**Résultat attendu** : Variables d'environnement chargées depuis `defaults.json` et `dev.env`.

---

### Test 3: Validation du spec builder

```bash
# Tester la génération de spec
source lib/logger.sh
source lib/config.sh
source lib/spec-builder.sh

load_config dev config
build_spec dev /tmp/test-spec.json config templates

# Vérifier le résultat
jq . /tmp/test-spec.json | head -30
```

---

## 🐛 Tests d'Erreurs

### Test 1: Environnement manquant

```bash
./druid-ingestion.sh build
# Résultat attendu: "Environment (-e) is required"
```

### Test 2: Environnement invalide

```bash
./druid-ingestion.sh build -e invalid
# Résultat attendu: "Invalid environment: invalid"
```

### Test 3: Fichier de config manquant

```bash
# Renommer temporairement
mv config/defaults.json config/defaults.json.bak
./druid-ingestion.sh build -e dev
# Résultat attendu: Erreur ou valeurs par défaut
mv config/defaults.json.bak config/defaults.json
```

### Test 4: Template manquant

```bash
# Renommer temporairement
mv templates/supervisor-spec.json.template templates/supervisor-spec.json.template.bak
./druid-ingestion.sh build -e dev
# Résultat attendu: "Template not found"
mv templates/supervisor-spec.json.template.bak templates/supervisor-spec.json.template
```

---

## 🚀 Test Complet (End-to-End)

### Scénario complet sans Druid

```bash
cd druid-ingestion

# 1. Compiler proto
./druid-ingestion.sh compile-proto

# 2. Générer spec
./druid-ingestion.sh build -e dev

# 3. Vérifier le résultat
jq . druid-specs/generated/supervisor-spec-*-dev.json | head -50
```

### Scénario complet avec Druid (local)

```bash
# Prérequis: Docker Compose avec Druid lancé
cd infrastructure
docker-compose up -d

# Attendre que Druid soit prêt (~1-2 minutes)
sleep 120

# Retour au module
cd ../druid-ingestion

# 1. Compiler proto
./druid-ingestion.sh compile-proto

# 2. Configurer pour local
cat > config/dev.env << EOF
KAFKA_BOOTSTRAP_SERVERS="localhost:9092"
KAFKA_SECURITY_PROTOCOL="PLAINTEXT"
KAFKA_TOPIC="settlement-transactions-dev"
DRUID_URL="http://localhost:8888"
DATASOURCE="idm_settlement_snapshot_dev"
PROTO_DESCRIPTOR_PATH="file:///opt/shared/schemas/settlement_transaction.desc"
PROTO_MESSAGE_TYPE="com.company.PaymentTransactionEvent"
EOF

# 3. Générer spec
./druid-ingestion.sh build -e dev

# 4. Déployer
./druid-ingestion.sh deploy -e dev

# 5. Vérifier statut
./druid-ingestion.sh status -e dev
```

---

## ✅ Checklist de Validation

- [ ] `./druid-ingestion.sh help` affiche l'aide
- [ ] `./druid-ingestion.sh compile-proto` génère un fichier `.desc`
- [ ] `./druid-ingestion.sh build -e dev` génère un JSON valide
- [ ] Le JSON généré contient toutes les sections requises
- [ ] Les variables d'environnement sont correctement substituées
- [ ] Les erreurs sont correctement gérées (environnement manquant, etc.)
- [ ] Les fonctions de logging fonctionnent (si test unitaire)
- [ ] Le déploiement fonctionne (si Druid accessible)
- [ ] Le statut fonctionne (si Druid accessible)

---

## 🔧 Dépannage

### Problème: "logger.sh not found"

```bash
# Vérifier que le fichier existe
ls -la lib/logger.sh

# Vérifier les permissions
chmod +x lib/logger.sh
```

### Problème: "jq: command not found"

```bash
# macOS
brew install jq

# Linux
apt-get install jq
```

### Problème: "envsubst: command not found"

```bash
# macOS
brew install gettext

# Linux
apt-get install gettext-base
```

### Problème: JSON invalide généré

```bash
# Vérifier le template
jq . templates/supervisor-spec.json.template

# Vérifier les variables
./druid-ingestion.sh build -e dev -o /tmp/test.json
jq . /tmp/test.json
```

---

## 📊 Tests Automatisés (Optionnel)

Créer un script de test simple:

```bash
#!/bin/bash
# test.sh

set -e

echo "🧪 Running tests..."

# Test 1: Help
echo "Test 1: Help"
./druid-ingestion.sh help > /dev/null && echo "✅ Pass" || echo "❌ Fail"

# Test 2: Compile proto
echo "Test 2: Compile proto"
./druid-ingestion.sh compile-proto > /dev/null && echo "✅ Pass" || echo "❌ Fail"

# Test 3: Build spec
echo "Test 3: Build spec"
./druid-ingestion.sh build -e dev > /dev/null && echo "✅ Pass" || echo "❌ Fail"

# Test 4: Validate JSON
echo "Test 4: Validate JSON"
jq empty druid-specs/generated/supervisor-spec-*-dev.json && echo "✅ Pass" || echo "❌ Fail"

echo "✅ All tests completed"
```

