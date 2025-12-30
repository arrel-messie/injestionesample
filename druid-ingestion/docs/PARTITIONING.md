# Secondary Partitioning Configuration

## Overview

Le module utilise un **secondary partitioning** (partitionnement secondaire) sur la dimension `payer_access_manager_id` pour optimiser les performances des requêtes.

## Justification

- **Cardinalité** : 5500 valeurs distinctes
- **Usage** : Présente dans 80% des patterns de requête
- **Bénéfice** : Amélioration significative des performances de filtrage et de GROUP BY

## Configuration

### Type de Partitioning

Le partitioning est configuré avec `type: "hashed"` qui utilise un hash de la dimension pour partitionner les segments :

```json
{
  "partitionsSpec": {
    "type": "hashed",
    "partitionDimensions": ["payer_access_manager_id"],
    "targetRowsPerSegment": 5000000
  }
}
```

### Variables d'Environnement

Dans les fichiers `.env`, la configuration est :

```bash
PARTITIONS_SPEC_TYPE="hashed"
SECONDARY_PARTITION_DIMENSIONS='["payer_access_manager_id"]'
TARGET_ROWS_PER_SEGMENT=5000000
```

## Comment ça fonctionne

1. **Partitioning primaire** : Par temps (segmentGranularity: DAY)
2. **Partitioning secondaire** : Par hash de `payer_access_manager_id`

Cela signifie que :
- Les segments sont d'abord partitionnés par jour
- Ensuite, chaque segment journalier est subdivisé par hash de `payer_access_manager_id`
- Les requêtes filtrant sur `payer_access_manager_id` peuvent scanner moins de segments

## Avantages

1. **Performance** : Réduction du nombre de segments à scanner pour les requêtes filtrant sur `payer_access_manager_id`
2. **Parallélisation** : Meilleure distribution de la charge entre les Historical nodes
3. **Cache** : Meilleure utilisation du cache de segments

## Exemple de Requête Optimisée

```sql
SELECT 
  tx_type,
  COUNT(*) as count,
  SUM(amount) as total
FROM idm_settlement_snapshot
WHERE payer_access_manager_id = '1234567'
  AND __time >= CURRENT_TIMESTAMP - INTERVAL '7' DAY
GROUP BY tx_type
```

Cette requête bénéficie du partitioning secondaire car :
- Seuls les segments contenant `payer_access_manager_id = '1234567'` sont scannés
- Les autres segments sont automatiquement exclus

## Monitoring

Pour vérifier l'efficacité du partitioning :

```sql
-- Vérifier la distribution des segments par payer_access_manager_id
SELECT 
  COUNT(DISTINCT segment_id) as segment_count,
  COUNT(*) as total_rows
FROM sys.segments
WHERE datasource = 'idm_settlement_snapshot'
  AND is_published = 1
GROUP BY partition_id
ORDER BY segment_count DESC
```

## Notes

- Le `targetRowsPerSegment` (5M lignes) contrôle la taille cible des segments
- Le partitioning secondaire fonctionne uniquement avec `type: "hashed"` ou `type: "range"`
- `payer_access_manager_id` doit être inclus dans les dimensions (pas dans `dimensionExclusions`)

