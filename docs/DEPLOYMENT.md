# Guide de déploiement

Procédures de déploiement pour tous les environnements.

## Workflow GitOps

```
develop  → Auto-deploy DEV
   ↓
staging  → Auto-deploy STAGING
   ↓
main     → Manual deploy PRODUCTION
```

## Déploiement standard

### 1. Modification du schéma Protobuf

```bash
# Branche feature
git checkout develop
git checkout -b feature/add-field

# Modifier
vim schemas/proto/settlement_transaction.proto
vim config/dimensions.json

# Test local
make compile
make test-template ENV=dev
make validate

# Push
git add schemas/ config/
git commit -m "feat: add new field"
git push origin feature/add-field

# Merge Request → develop
# Pipeline déploie automatiquement en DEV
```

### 2. Promotion vers staging

```bash
git checkout staging
git merge develop
git push origin staging
# Auto-deploy STAGING
```

### 3. Promotion vers production

```bash
git checkout main
git merge staging
git push origin main
# Dans GitLab CI/CD, cliquer "Play" sur deploy:prod
```

## Déploiement local

```bash
# Déployer en DEV
make deploy-dev

# Déployer en STAGING
make deploy-staging

# Déployer en PRODUCTION
make deploy-prod
```

## Rollback

### Option A : Rollback Git
```bash
git revert <commit>
git push origin main
# Redéployer manuellement
```

### Option B : Rollback schéma uniquement
```bash
# Lister les versions
make list-schemas

# Rollback
make rollback ENV=prod VERSION=abc123f
```

## Vérifications post-déploiement

### Checklist

1. **Statut superviseur**
   ```bash
   make status ENV=prod
   # État attendu : "RUNNING"
   ```

2. **Tâches d'indexation**
   ```bash
   make logs ENV=prod
   # Vérifier taskCount et status
   ```

3. **Taux d'ingestion**
   Console Druid → Supervisors → Vérifier ingestion rate > 0

4. **Erreurs de parsing**
   ```bash
   curl http://druid:8090/druid/indexer/v1/supervisor/datasource/status | \
     jq '.payload.aggregateReportData[0].currentEvents.unparseableEvents'
   # Doit être proche de 0
   ```

5. **Requête test**
   ```bash
   curl -X POST http://druid:8082/druid/v2/sql \
     -H 'Content-Type: application/json' \
     -d '{"query":"SELECT COUNT(*) FROM datasource WHERE __time > CURRENT_TIMESTAMP - INTERVAL '\''1'\'' HOUR"}'
   ```

## Monitoring

### Métriques importantes

| Métrique | Seuil alerte | Action |
|----------|--------------|--------|
| Supervisor state | != RUNNING | Investiguer |
| Task failures | > 5% | Vérifier parsing |
| Ingestion lag | > 5 min | Augmenter taskCount |
| Parse exceptions | > 1% | Vérifier schéma |

### Commandes de monitoring

```bash
# Statut
make status ENV=prod

# Logs
make logs ENV=prod

# Lister schémas S3
make list-schemas
```

## Gestion des versions

### Structure S3
```
s3://bucket/schemas/
├── abc123f/           # Version spécifique (commit SHA)
├── develop-latest/    # Dernière version develop
├── staging-latest/    # Dernière version staging
└── stable/            # Version stable (production)
```

### Compatibilité des schémas

**Changements compatibles (safe) :**
- ✅ Ajout champs optionnels
- ✅ Ajout nouveaux messages
- ✅ Changement commentaires

**Changements incompatibles (breaking) :**
- ❌ Suppression de champs
- ❌ Changement de type
- ❌ Changement numéro de champ

Pour les breaking changes : créer nouveau datasource.

## Calendrier recommandé

### Production
- **Mardi-Mercredi** : Déploiements standard
- **Éviter lundi** (retour weekend)
- **Éviter vendredi** (support weekend limité)
- **Fenêtre** : 10h-16h

### Staging/Dev
- **Lundi-Vendredi** : Anytime

## Procédure d'urgence

En cas de problème majeur :

1. **Suspendre le superviseur**
   ```bash
   curl -X POST http://druid:8090/druid/indexer/v1/supervisor/datasource/suspend
   ```

2. **Notifier l'équipe**

3. **Analyser** les logs

4. **Rollback** si nécessaire
   ```bash
   make rollback ENV=prod VERSION=previous-stable
   ```

5. **Post-mortem** : documenter l'incident

## Support

- **Équipe Data Engineering** : #data-eng sur Slack
- **Escalation** : data-eng-lead@company.com
- **Documentation** : docs/
