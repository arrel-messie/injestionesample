# Changelog

Tous les changements notables de ce projet seront documentés dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.0.0] - 2025-01-XX

### Ajouté
- Pipeline CI/CD GitLab complet avec envsubst (natif)
- Compilation automatique des schémas Protobuf
- Upload vers S3 avec versioning (commit SHA, latest, stable)
- Déploiement automatisé sur dev/staging, manuel sur prod
- Scripts de déploiement et rollback utilisant envsubst
- Template JSON pour specs Druid (pas de dépendance Python)
- Configuration par environnement (dev/staging/prod)
- Support SASL_SSL pour Kafka
- Gestion des dimensions via JSON
- Makefile avec commandes pratiques
- Documentation complète (README, QUICKSTART, SETUP, DEPLOYMENT)

### Caractéristiques techniques
- **Zero dépendance externe** : envsubst + jq + curl (tous pré-installés)
- **Standard de l'industrie** : approche utilisée par Kubernetes, Docker
- **Performant** : images Docker légères, génération rapide
- Datasource: `idm_settlement_snapshot`
- Topic Kafka: `settlement-transactions-{env}`
- Schéma: `com.company.settlement.Transaction`
- Segment granularity: DAY
- 15 dimensions définies
