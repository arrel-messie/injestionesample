# Druid Ingestion Manager - Shell Solution

Solution shell professionnelle et industrialisable avec séparation des responsabilités, templating et utilisation des configs externes.

## 🎯 Objectif

Solution shell modulaire et maintenable pour gérer les déploiements de supervisors Druid, avec une architecture similaire à la version Java mais en bash.

## ✅ Architecture Simplifiée

```
druid-ingestion/
├── druid-ingestion.sh          # Script principal (tout-en-un)
├── lib/                        # Modules complexes uniquement
│   ├── config.sh               # Chargement des configs (defaults.yml, .env, schema.yml)
│   └── spec-builder.sh         # Génération de spec depuis template
├── templates/                   # Templates JSON
│   └── supervisor-spec.json.template
└── config/                      # Configurations externes
    ├── defaults.yml             # Valeurs par défaut
    ├── schema.yml               # Schéma Druid (dimensions, metrics, transforms, index)
    ├── dev.env                  # Variables d'environnement dev
    ├── staging.env              # Variables d'environnement staging
    └── prod.env                 # Variables d'environnement prod
```

**Philosophie** : Structure simple, pas d'over-engineering. Seuls les modules complexes (config, spec-builder) sont séparés. Le reste est intégré dans le script principal.

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

### Architecture simplifiée

- **`druid-ingestion.sh`** : Script principal avec toutes les fonctions simples intégrées
  - Logging avec couleurs
  - Validation des entrées
  - Requêtes HTTP avec retry simplifié
  - Vérification des prérequis
  - Commandes build/deploy/status
- **`lib/config.sh`** : Chargement et fusion des configs (complexe, séparé)
- **`lib/spec-builder.sh`** : Construction de la spec JSON (complexe, séparé)

### Templating

- **`templates/supervisor-spec.json.template`** : Template JSON avec variables
- Génération de spec via `jq` pour manipulation JSON propre
- Substitution des variables depuis configs externes

### Gestion d'erreurs

- `set -euo pipefail` : Arrêt sur erreur
- Validation des paramètres
- Messages d'erreur clairs
- Retry logic simplifié pour HTTP

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
| **Structure** | Simplifiée (1 script + 2 modules) | Modulaire (packages) |
| **Templating** | Template JSON + jq | Construction directe |
| **Configs** | defaults.yml + .env + schema.yml | defaults.yml + .env + schema.yml |
| **Lignes** | ~706 (simplifié) | ~1095 |
| **Fichiers** | 3 fichiers shell | ~20 fichiers Java |
| **Dépendances** | jq, curl, yq | Maven + 8 libs |
| **Maintenabilité** | Excellente (simple) | Excellente (packages) |

## 🎓 Pour un développeur Java

### Points familiers

1. **Script principal** : `druid-ingestion.sh` = classe principale avec méthodes utilitaires
2. **Modules complexes** : `lib/` = classes complexes séparées
3. **Templates** : `templates/` = templates de configuration
4. **Configs** : `config/` = fichiers de configuration

### Philosophie de simplicité

- **Pas d'over-engineering** : Seuls les modules complexes sont séparés
- **Fonctions simples intégrées** : Logging, validation, HTTP dans le script principal
- **Facile à comprendre** : Tout est visible dans un seul fichier principal
- **Maintenable** : Moins de fichiers = moins de complexité

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
