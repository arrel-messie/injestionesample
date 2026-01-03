# Druid Ingestion Manager - Shell Solution

Solution shell professionnelle et industrialisable avec séparation des responsabilités, templating et utilisation des configs externes.

## 🎯 Objectif

Solution shell modulaire et maintenable pour gérer les déploiements de supervisors Druid, avec une architecture similaire à la version Java mais en bash.

## ✅ Architecture Modulaire

```
druid-ingestion/
├── druid-ingestion.sh          # Point d'entrée principal (orchestration)
├── lib/                        # Modules réutilisables
│   ├── logger.sh               # Logging centralisé
│   ├── validator.sh             # Validation des entrées
│   ├── config.sh                # Chargement des configs (defaults.yml, .env, schema.yml)
│   ├── spec-builder.sh         # Génération de spec depuis template
│   ├── http-client.sh           # Client HTTP avec retry
│   └── prerequisites.sh         # Vérification des outils
├── commands/                    # Commandes séparées
│   ├── build.sh                # Commande build
│   ├── deploy.sh               # Commande deploy
│   └── status.sh               # Commande status
├── templates/                   # Templates JSON
│   └── supervisor-spec.json.template
└── config/                      # Configurations externes
    ├── defaults.yml             # Valeurs par défaut
    ├── schema.yml               # Schéma Druid (dimensions, metrics, transforms, index)
    ├── dev.env                  # Variables d'environnement dev
    ├── staging.env              # Variables d'environnement staging
    └── prod.env                 # Variables d'environnement prod
```

## 📋 Prérequis

```bash
# macOS
brew install jq curl gettext yq

# Ubuntu/Debian
sudo apt-get install -y jq curl gettext-base yq

# Vérifier
jq --version
curl --version
envsubst --version
yq --version
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

## ⚙️ Configuration

### 1. Fichier `defaults.yml`

Contient les valeurs par défaut pour tous les environnements (Kafka, Druid, Task, Tuning, Granularity).

### 2. Fichier `schema.yml`

Définit le schéma Druid :
- `dimensions`: Liste des dimensions
- `metrics`: Liste des métriques
- `transforms`: Liste des transformations
- `indexSpec`: Configuration d'indexation

### 3. Fichiers `.env` par environnement

Variables spécifiques à chaque environnement qui surchargent `defaults.yml` :

```bash
# config/dev.env
KAFKA_BOOTSTRAP_SERVERS="localhost:9092"
KAFKA_TOPIC="settlement-transactions-dev"
DRUID_URL="http://localhost:8888"
DATASOURCE="idm_settlement_snapshot_dev"
PROTO_DESCRIPTOR_PATH="file:///opt/shared/schemas/settlement_transaction.desc"
```

## 🔧 Fonctionnalités

### Séparation des responsabilités

- **`lib/logger.sh`** : Logging centralisé avec couleurs
- **`lib/validator.sh`** : Validation des entrées
- **`lib/config.sh`** : Chargement et fusion des configs
- **`lib/spec-builder.sh`** : Construction de la spec JSON
- **`lib/http-client.sh`** : Requêtes HTTP avec retry
- **`lib/prerequisites.sh`** : Vérification des outils

### Templating

- **`templates/supervisor-spec.json.template`** : Template JSON avec variables
- Génération de spec via `jq` pour manipulation JSON propre
- Substitution des variables depuis configs externes

### Commandes modulaires

- **`commands/build.sh`** : Génère la spec JSON
- **`commands/deploy.sh`** : Déploie vers Druid
- **`commands/status.sh`** : Récupère le statut

### Gestion d'erreurs

- `set -euo pipefail` : Arrêt sur erreur
- Validation des paramètres
- Messages d'erreur clairs
- Retry logic pour HTTP

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
| **Structure** | Modulaire (lib/, commands/) | Modulaire (packages) |
| **Templating** | Template JSON + jq | Construction directe |
| **Configs** | defaults.yml + .env + schema.yml | defaults.yml + .env + schema.yml |
| **Lignes** | ~600 (modulaire) | ~1095 |
| **Dépendances** | jq, curl, yq | Maven + 8 libs |
| **Maintenabilité** | Excellente (modules) | Excellente (packages) |

## 🎓 Pour un développeur Java

### Points familiers

1. **Modules** : `lib/` = packages Java
2. **Commandes** : `commands/` = classes de commande
3. **Templates** : `templates/` = templates de configuration
4. **Configs** : `config/` = fichiers de configuration
5. **Logging** : `lib/logger.sh` = logger Java
6. **Validation** : `lib/validator.sh` = validation Java

### Architecture similaire

- **Séparation des responsabilités** : Chaque module a une responsabilité unique
- **Réutilisabilité** : Modules importables (`source`)
- **Testabilité** : Modules testables indépendamment
- **Extensibilité** : Facile d'ajouter de nouvelles commandes

## 🔍 Debugging

### Mode verbose

```bash
# Activer le mode debug
DEBUG=1 ./druid-ingestion.sh build -e dev
```

### Vérifier la configuration

```bash
# Voir les valeurs chargées
source config/dev.env
env | grep -E "(KAFKA|DRUID|DATASOURCE)"
```

## ✅ Checklist pour production

- [ ] Scripts avec permissions d'exécution (`chmod +x`)
- [ ] Variables sensibles dans `.env` (pas dans git)
- [ ] Validation des URLs Druid
- [ ] Tests avec `shellcheck`
- [ ] Documentation à jour
- [ ] Template JSON validé

## 📚 Ressources

- [jq Manual](https://stedolan.github.io/jq/manual/)
- [yq Documentation](https://mikefarah.gitbook.io/yq/)
- [Bash Best Practices](https://mywiki.wooledge.org/BashGuide)
- [ShellCheck](https://www.shellcheck.net/)
