# Druid Ingestion Manager - Shell Solution

Solution shell professionnelle et industrialisable pour gérer les déploiements de supervisors Druid.

## 🎯 Objectif

Cette solution shell remplace l'application Java par des scripts bash professionnels, maintenables et faciles à comprendre pour un développeur Java.

## ✅ Avantages

- **Simple** : Scripts bash faciles à comprendre
- **Léger** : Pas de compilation, pas de JAR
- **Rapide** : Exécution directe
- **Standard** : Utilise `jq`, `yq`, `curl` (outils standard)
- **Maintenable** : Code structuré avec fonctions réutilisables

## 📋 Prérequis

```bash
# macOS
brew install jq yq

# Ubuntu/Debian
sudo apt-get install -y jq yq curl

# Vérifier
jq --version
yq --version
curl --version
```

## 🚀 Utilisation

### Build (Générer la spec)

```bash
./druid-ingestion.sh build -e dev
./druid-ingestion.sh build -e dev -o /tmp/custom-spec.json
```

### Deploy (Déployer)

```bash
./druid-ingestion.sh deploy -e dev
./druid-ingestion.sh deploy -e staging
./druid-ingestion.sh deploy -e prod
```

### Status (Statut)

```bash
./druid-ingestion.sh status -e dev
```

## 📁 Structure

```
druid-ingestion/
├── druid-ingestion.sh      # Script principal
├── config/
│   ├── defaults.yml        # Valeurs par défaut
│   ├── schema.yml          # Schéma Druid (dimensions, metrics, etc.)
│   ├── dev.env             # Configuration dev
│   ├── staging.env         # Configuration staging
│   └── prod.env            # Configuration prod
└── druid-specs/
    └── generated/          # Specs générées
```

## ⚙️ Configuration

### 1. Fichier `.env` par environnement

```bash
# config/dev.env
KAFKA_BOOTSTRAP_SERVERS="localhost:9092"
KAFKA_TOPIC="settlement-transactions-dev"
DRUID_URL="http://localhost:8888"
DATASOURCE="idm_settlement_snapshot_dev"
PROTO_DESCRIPTOR_PATH="file:///opt/shared/schemas/settlement_transaction.desc"
```

### 2. Fichier `defaults.yml`

Contient les valeurs par défaut (voir `config/defaults.yml`).

### 3. Fichier `schema.yml`

Contient la définition du schéma Druid (voir `config/schema.yml`).

## 🔧 Fonctionnalités

### Gestion d'erreurs

- `set -euo pipefail` : Arrêt sur erreur
- Validation des paramètres
- Messages d'erreur clairs

### Logging

- Couleurs pour la lisibilité
- Niveaux : INFO, WARN, ERROR
- Sortie sur stderr (compatible scripts)

### Validation

- Vérification des prérequis (`jq`, `yq`, `curl`)
- Validation de l'environnement
- Validation des URLs

## 📝 Exemples

### Build avec sortie personnalisée

```bash
./druid-ingestion.sh build -e dev -o /tmp/my-spec.json
```

### Deploy avec validation automatique

```bash
# Le script vérifie automatiquement si la spec existe
# et la génère si nécessaire
./druid-ingestion.sh deploy -e dev
```

### Status avec formatage JSON

```bash
# Le JSON est automatiquement formaté avec jq
./druid-ingestion.sh status -e dev
```

## 🆚 Comparaison avec la solution Java

| Aspect | Shell | Java |
|--------|-------|------|
| **Taille** | ~400 lignes | ~1095 lignes |
| **Dépendances** | jq, yq, curl | Maven + 8 libs |
| **Compilation** | Non | Oui |
| **Démarrage** | Instantané | ~100ms |
| **Maintenabilité** | Facile (bash) | Facile (Java) |
| **Tests** | Shellcheck | JUnit |
| **Portabilité** | Linux/macOS | Toute plateforme |

## 🎓 Pour un développeur Java

### Points familiers

1. **Structure modulaire** : Fonctions = méthodes
2. **Gestion d'erreurs** : `error_exit()` = exceptions
3. **Configuration** : `.env` = properties
4. **Logging** : `log_info()` = logger

### Différences clés

- **Variables** : `$VAR` au lieu de `var`
- **Fonctions** : `function_name() { ... }` au lieu de méthodes
- **Conditions** : `[ condition ]` au lieu de `if (condition)`
- **JSON** : `jq` au lieu de Jackson

## 🔍 Debugging

### Mode verbose

```bash
# Ajouter -x pour voir les commandes exécutées
bash -x ./druid-ingestion.sh build -e dev
```

### Vérifier la configuration

```bash
# Voir les valeurs chargées
source config/dev.env
echo $DRUID_URL
```

## 📚 Ressources

- [jq Manual](https://stedolan.github.io/jq/manual/)
- [yq Documentation](https://mikefarah.gitbook.io/yq/)
- [Bash Best Practices](https://mywiki.wooledge.org/BashGuide)

## ✅ Checklist pour production

- [ ] Scripts avec permissions d'exécution (`chmod +x`)
- [ ] Variables sensibles dans `.env` (pas dans git)
- [ ] Validation des URLs Druid
- [ ] Tests avec `shellcheck`
- [ ] Documentation à jour

