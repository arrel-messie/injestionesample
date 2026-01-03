# Druid Ingestion Manager

Shell script pour gérer les déploiements de supervisors Druid.

## Prérequis

```bash
brew install jq curl gettext
```

## Utilisation

```bash
./druid-ingestion.sh build -e dev
./druid-ingestion.sh deploy -e dev
./druid-ingestion.sh status -e dev
./druid-ingestion.sh compile-proto
```

## Configuration

Les configurations sont dans `config/` :
- `dev.env`, `staging.env`, `prod.env` : Variables par environnement
- `schema.json` : Schéma Druid (dimensions, metrics, transforms)

## Structure

```
druid-ingestion/
├── druid-ingestion.sh      # Script principal
├── lib/                    # Modules
│   ├── logger.sh           # Logging
│   └── spec-builder.sh     # Génération spec
├── druid-specs/            # Specs et templates
│   ├── templates/          # Templates JSON
│   └── generated/          # Specs générées
├── config/                 # Configurations
└── docs/                   # Documentation
```

## CI/CD

Voir `docs/CI_CD.md` pour la configuration GitLab CI.

