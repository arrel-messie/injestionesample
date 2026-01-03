# Organisation des Packages

## Structure proposée

```
com.company.druid/
├── cli/                    # Point d'entrée CLI
│   └── DruidIngestion.java
│
├── config/                 # Gestion de la configuration
│   ├── Config.java
│   ├── ConfigLoader.java
│   └── ConfigBuilder.java
│
├── schema/                 # Définition et chargement du schéma
│   ├── Schema.java
│   └── SchemaLoader.java
│
├── spec/                   # Construction des specs Druid
│   └── SpecBuilder.java
│
├── client/                 # Clients externes
│   ├── HttpClient.java
│   └── S3Uploader.java
│
├── util/                   # Utilitaires
│   └── Validator.java
│
└── exceptions/             # Exceptions (déjà organisé)
    ├── ConfigException.java
    ├── DruidException.java
    └── ValidationException.java
```

## Justification

### `cli/`
- **DruidIngestion** : Point d'entrée de l'application CLI
- Responsabilité unique : Gestion des commandes CLI

### `config/`
- **Config** : Record de configuration
- **ConfigLoader** : Chargement depuis fichiers .env
- **ConfigBuilder** : Builder pattern pour construction
- Cohésion : Toutes les classes liées à la configuration

### `schema/`
- **Schema** : Record de définition du schéma
- **SchemaLoader** : Chargement depuis YAML
- Cohésion : Toutes les classes liées au schéma Druid

### `spec/`
- **SpecBuilder** : Construction des specs JSON pour Druid
- Responsabilité : Transformation Config + Schema → Spec JSON

### `client/`
- **HttpClient** : Client HTTP pour API Druid
- **S3Uploader** : Client S3 pour upload de descriptors
- Cohésion : Toutes les interactions avec services externes

### `util/`
- **Validator** : Validation d'entrées (env, URLs)
- Utilitaires réutilisables

### `exceptions/`
- Déjà bien organisé
- Exceptions métier

## Avantages

1. **Séparation des responsabilités** : Chaque package a un rôle clair
2. **Maintenabilité** : Facile de trouver où modifier une fonctionnalité
3. **Testabilité** : Packages isolés, tests unitaires plus simples
4. **Scalabilité** : Facile d'ajouter de nouvelles fonctionnalités
5. **Standards** : Organisation conforme aux bonnes pratiques Java

## Migration

Les imports seront mis à jour automatiquement lors du déplacement des fichiers.

