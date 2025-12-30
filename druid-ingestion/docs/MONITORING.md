# Monitoring et Validation des Données

## Transformations de Normalisation

Le module applique automatiquement des transformations de normalisation sur les champs string pour améliorer la qualité des données :

### Champs Normalisés

Les champs suivants sont automatiquement normalisés en uppercase tout en conservant leurs noms originaux du proto :
- `tx_type` : Normalisé en uppercase (remplace la valeur originale)
- `status` : Normalisé en uppercase (remplace la valeur originale)
- `currency` : Normalisé en uppercase (remplace la valeur originale)
- `reason_code` : Normalisé en uppercase (remplace la valeur originale)
- `payment_type_code` : Normalisé en uppercase (remplace la valeur originale)

### Avantages

1. **Cohérence** : Toutes les valeurs sont en uppercase, évite les variations de casse
2. **Performance** : GROUP BY plus efficace avec des valeurs normalisées
3. **Qualité** : Réduction des doublons dus aux variations de casse

## Validation des Valeurs

### Valeurs Attendues pour `tx_type`

Les valeurs valides selon le proto sont :
- `ONLINE_FUNDING`
- `ONLINE_DEFUNDING`
- `SIMPLE_PAYMENT`
- `COMBINED_PAYMENT`

### Requêtes de Monitoring

#### Détecter les valeurs invalides de tx_type

```sql
SELECT 
  tx_type,
  COUNT(*) as count
FROM idm_settlement_snapshot
WHERE tx_type NOT IN (
  'ONLINE_FUNDING',
  'ONLINE_DEFUNDING',
  'SIMPLE_PAYMENT',
  'COMBINED_PAYMENT'
)
GROUP BY tx_type
ORDER BY count DESC
```

#### Distribution des types de transaction

```sql
SELECT 
  tx_type,
  COUNT(*) as count,
  SUM(amount) as total_amount
FROM idm_settlement_snapshot
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '1' DAY
GROUP BY tx_type
ORDER BY count DESC
```

#### Détecter les valeurs de status inattendues

```sql
SELECT 
  status,
  COUNT(*) as count
FROM idm_settlement_snapshot
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '1' DAY
GROUP BY status
ORDER BY count DESC
```

#### Détecter les devises inattendues

```sql
SELECT 
  currency,
  COUNT(*) as count
FROM idm_settlement_snapshot
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '1' DAY
GROUP BY currency
ORDER BY count DESC
```

## Filtre de Validation Optionnel

Pour activer le filtrage des valeurs invalides de `tx_type`, ajoutez dans votre fichier `.env` :

```bash
TX_TYPE_VALIDATION_FILTER='{"type": "in", "dimension": "tx_type", "values": ["ONLINE_FUNDING", "ONLINE_DEFUNDING", "SIMPLE_PAYMENT", "COMBINED_PAYMENT"]}'
```

**Attention** : Ce filtre rejette les lignes avec des valeurs invalides. Utilisez avec précaution en production.

## Alertes Recommandées

### 1. Valeurs invalides de tx_type

Créer une alerte si le nombre de valeurs invalides dépasse un seuil :

```sql
SELECT COUNT(*) as invalid_count
FROM idm_settlement_snapshot
WHERE tx_type NOT IN (
  'ONLINE_FUNDING',
  'ONLINE_DEFUNDING',
  'SIMPLE_PAYMENT',
  'COMBINED_PAYMENT'
)
AND __time >= CURRENT_TIMESTAMP - INTERVAL '1' HOUR
```

### 2. Volume de données anormal

Surveiller le volume horaire :

```sql
SELECT 
  TIME_FLOOR(__time, 'PT1H') as hour,
  COUNT(*) as message_count
FROM idm_settlement_snapshot
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
GROUP BY 1
ORDER BY 1 DESC
```

### 3. Taux d'erreur (status FAILED)

```sql
SELECT 
  TIME_FLOOR(__time, 'PT1H') as hour,
  COUNT(*) FILTER (WHERE status_normalized = 'FAILED') as failed_count,
  COUNT(*) as total_count,
  100.0 * COUNT(*) FILTER (WHERE status_normalized = 'FAILED') / COUNT(*) as failure_rate
FROM idm_settlement_snapshot
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
GROUP BY 1
ORDER BY 1 DESC
```

## Métriques Disponibles

Les métriques suivantes sont automatiquement calculées :

- `count` : Nombre total de transactions
- `amount_sum` : Somme des montants
- `amount_min` : Montant minimum
- `amount_max` : Montant maximum

Exemple d'utilisation :

```sql
SELECT 
  tx_type,
  SUM(count) as transaction_count,
  SUM(amount_sum) as total_amount,
  MIN(amount_min) as min_amount,
  MAX(amount_max) as max_amount
FROM idm_settlement_snapshot
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '1' DAY
GROUP BY tx_type
```

## Dashboard Recommandé

Créer un dashboard avec les panneaux suivants :

1. **Volume** : Nombre de transactions par heure
2. **Distribution** : Répartition par `tx_type`
3. **Status** : Répartition par `status`
4. **Montants** : Total, min, max par type de transaction
5. **Qualité** : Nombre de valeurs invalides détectées
6. **Devises** : Répartition par `currency`

