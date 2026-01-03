# Proposition d'Optimisation - Spec Builder

## 🎯 Idée Proposée

**Approche simplifiée** :
1. Le fichier `.env` contient **TOUT** (valeurs par défaut + overrides)
2. Charger `schema.json` pour dimensions/metrics/transforms/indexSpec
3. Une seule substitution dans le template avec `envsubst`
4. Plus besoin de `defaults.json` ni de `_export_template_vars()` complexe

## 📊 État Actuel vs Proposé

### Actuel (Complexe)
```
1. load_config() charge defaults.json + .env
2. _export_template_vars() lit defaults.json et exporte 30+ variables
3. _load_index_spec() lit schema.json pour indexSpec
4. build_spec() fait sed + envsubst
```

**Lignes de code** : ~105 lignes dans spec-builder.sh + 65 lignes dans config.sh = **170 lignes**

### Proposé (Simplifié)
```
1. load_config() charge uniquement .env (qui contient tout)
2. _load_schema() lit schema.json pour dimensions/metrics/transforms/indexSpec
3. build_spec() fait sed (pour schema) + envsubst (pour config)
```

**Lignes de code estimées** : ~50 lignes dans spec-builder.sh + 30 lignes dans config.sh = **80 lignes**

**Gain estimé** : **90 lignes (-53%)**

## 🔄 Changements Proposés

### 1. Simplifier `config.sh`

**Avant** (65 lignes) :
```bash
load_config() {
    # Charge defaults.json avec mapping table
    # Charge .env pour overrides
    # 65 lignes
}
```

**Après** (30 lignes) :
```bash
load_config() {
    local env="$1" config_dir="$2"
    local env_file="${config_dir}/${env}.env"
    [ -f "$env_file" ] && set -a && source "$env_file" && set +a
    export ENV="$env"
}
```

### 2. Simplifier `spec-builder.sh`

**Avant** (105 lignes) :
- `_export_template_vars()` : 20 lignes (lecture defaults.json)
- `_load_index_spec()` : 4 lignes
- `_build_dimensions_spec()` : 8 lignes
- `_build_metrics_spec()` : 3 lignes
- `_build_transforms_spec()` : 6 lignes
- `build_spec()` : 30 lignes

**Après** (50 lignes) :
- `_load_schema()` : 10 lignes (charge tout depuis schema.json)
- `build_spec()` : 25 lignes (sed + envsubst)

### 3. Structure du `.env` Complet

Le fichier `.env` contiendrait **toutes** les valeurs :

```bash
# Kafka
KAFKA_BOOTSTRAP_SERVERS="localhost:9092"
KAFKA_SECURITY_PROTOCOL="PLAINTEXT"
KAFKA_SASL_MECHANISM="PLAIN"
KAFKA_SASL_JAAS_CONFIG=""
KAFKA_SSL_ENDPOINT_ID=""
KAFKA_TOPIC="settlement-transactions-dev"
KAFKA_FETCH_MIN_BYTES=1048576
KAFKA_FETCH_MAX_WAIT_MS=500
KAFKA_MAX_POLL_RECORDS=500
KAFKA_SESSION_TIMEOUT_MS=30000
KAFKA_HEARTBEAT_INTERVAL_MS=3000
KAFKA_MAX_POLL_INTERVAL_MS=300000
KAFKA_AUTO_OFFSET_RESET=latest

# Proto
PROTO_DESCRIPTOR_PATH="file:///opt/shared/schemas/settlement_transaction.desc"
PROTO_MESSAGE_TYPE="com.company.PaymentTransactionEvent"

# Druid
DRUID_URL="http://localhost:8888"
DATASOURCE="idm_settlement_snapshot_dev"
DRUID_TIMESTAMP_COLUMN="settlementTimestampMs"
DRUID_TIMESTAMP_FORMAT="millis"

# Task
TASK_USE_EARLIEST_OFFSET=false
TASK_USE_TRANSACTION=true
TASK_COUNT=10
TASK_REPLICAS=2
TASK_DURATION="PT1H"
TASK_START_DELAY="PT5S"
TASK_PERIOD="PT30S"
TASK_COMPLETION_TIMEOUT="PT1H"
TASK_LATE_MESSAGE_REJECTION_PERIOD="PT1H"
TASK_POLL_TIMEOUT=100
TASK_MINIMUM_MESSAGE_TIME="1970-01-01T00:00:00.000Z"

# Tuning
TUNING_MAX_ROWS_IN_MEMORY=500000
TUNING_MAX_BYTES_IN_MEMORY=536870912
TUNING_MAX_ROWS_PER_SEGMENT=5000000
TUNING_MAX_PENDING_PERSISTS=2
TUNING_REPORT_PARSE_EXCEPTIONS=true
TUNING_HANDOFF_CONDITION_TIMEOUT=900000
TUNING_RESET_OFFSET_AUTOMATICALLY=false
TUNING_CHAT_RETRIES=8
TUNING_HTTP_TIMEOUT="PT10S"
TUNING_SHUTDOWN_TIMEOUT="PT80S"
TUNING_OFFSET_FETCH_PERIOD="PT30S"
TUNING_INTERMEDIATE_HANDOFF_PERIOD="P2147483647D"
TUNING_LOG_PARSE_EXCEPTIONS=true
TUNING_MAX_PARSE_EXCEPTIONS=10000
TUNING_MAX_SAVED_PARSE_EXCEPTIONS=100
TUNING_SKIP_SEQUENCE_NUMBER_AVAILABILITY_CHECK=false
TUNING_PARTITIONS_SPEC_TYPE=dynamic
TUNING_SECONDARY_PARTITION_DIMENSIONS=[]
TUNING_TARGET_ROWS_PER_SEGMENT=5000000
TUNING_MAX_SPLIT_SIZE=1073741824
TUNING_MAX_INPUT_SEGMENT_BYTES_PER_TASK=10737418240

# Granularity
GRANULARITY_SEGMENT=DAY
GRANULARITY_QUERY=NONE
GRANULARITY_ROLLUP=false

# Index Spec (peut aussi venir de schema.json)
INDEX_SPEC_BITMAP_TYPE=roaring
INDEX_SPEC_DIMENSION_COMPRESSION=lz4
INDEX_SPEC_METRIC_COMPRESSION=lz4
INDEX_SPEC_LONG_ENCODING=longs
```

## ✅ Avantages

1. **Single Source of Truth** : Un seul fichier `.env` par environnement
2. **Code plus simple** : Plus de mapping table, plus de lecture JSON complexe
3. **Moins de code** : ~90 lignes en moins
4. **Plus facile à maintenir** : Tout est dans le `.env`
5. **Plus flexible** : Chaque environnement a son propre `.env` complet

## ⚠️ Inconvénients

1. **Duplication entre .env** : Les valeurs par défaut sont répétées dans chaque `.env`
   - **Solution** : Utiliser un `.env.example` comme template

2. **Migration nécessaire** : Il faut migrer `defaults.json` vers les `.env`
   - **Solution** : Script de migration automatique

## 🚀 Implémentation Proposée

### Étape 1: Créer un script de migration

```bash
# migrate-defaults.sh
# Convertit defaults.json en .env.example
jq -r 'to_entries[] | "\(.key | ascii_upcase)=\"\(.value)\""' defaults.json
```

### Étape 2: Simplifier config.sh

```bash
load_config() {
    local env="$1" config_dir="${2:-$(dirname "${BASH_SOURCE[0]}")/../config}"
    [ -z "$env" ] && log_error "Environment is required" && return 1
    [[ ! "$env" =~ ^(dev|staging|prod|test)$ ]] && log_error "Invalid environment: $env" && return 1
    
    local env_file="${config_dir}/${env}.env"
    [ ! -f "$env_file" ] && log_error "Config file not found: $env_file" && return 1
    
    set -a
    source "$env_file"
    set +a
    
    [ -n "${DRUID_URL:-}" ] && [[ ! "${DRUID_URL}" =~ ^https?:// ]] && {
        log_error "Invalid DRUID_URL: ${DRUID_URL}"
        return 1
    }
    
    export ENV="$env"
}
```

### Étape 3: Simplifier spec-builder.sh

```bash
# Charger tout depuis schema.json
_load_schema() {
    local schema_file="$1"
    export DIMENSIONS_SPEC=$(jq -c '{
        dimensions: (.dimensions // []),
        dimensionExclusions: ["settlement_ts", "settlement_entry_ts", "acceptance_ts", "payee_access_manager_id"],
        includeAllDimensions: false,
        useSchemaDiscovery: false
    }' "$schema_file")
    
    export METRICS_SPEC=$(jq -c '.metrics // []' "$schema_file")
    
    export TRANSFORMS_SPEC=$(jq -c '{
        transforms: ((.transforms // []) | map({type: "expression", name: .name, expression: .expression})),
        filter: null
    }' "$schema_file")
    
    # Index spec depuis schema.json ou variables d'env
    eval "$(jq -r '.indexSpec | to_entries[] | "export INDEX_SPEC_\(.key | ascii_upcase)=\"\(.value)\""' "$schema_file" 2>/dev/null || echo '')"
}

# Build spec (simplifié)
build_spec() {
    local env="${1:-}" output="${2:-}" config_dir="${3:-}" template_dir="${4:-}"
    
    [ -z "$env" ] && log_error "Environment is required" && return 1
    export ENV="$env"
    
    local schema_file="${config_dir}/schema.json"
    [ ! -f "$schema_file" ] && log_error "Schema not found: $schema_file" && return 1
    
    local template_file="${template_dir}/supervisor-spec.json.template"
    [ ! -f "$template_file" ] && log_error "Template not found: $template_file" && return 1
    
    _load_schema "$schema_file"
    
    [ -z "$output" ] && output="$(dirname "$(dirname "$config_dir")")/druid-specs/generated/supervisor-spec-${DATASOURCE}-${env}.json"
    mkdir -p "$(dirname "$output")"
    
    local temp_file=$(mktemp)
    sed -e "s|__DIMENSIONS_SPEC__|$DIMENSIONS_SPEC|g" \
        -e "s|__METRICS_SPEC__|$METRICS_SPEC|g" \
        -e "s|__TRANSFORM_SPEC__|$TRANSFORMS_SPEC|g" "$template_file" > "$temp_file"
    
    envsubst < "$temp_file" > "$output"
    rm -f "$temp_file"
    
    jq empty "$output" 2>/dev/null || { log_error "Invalid JSON"; return 1; }
    echo "$output"
}
```

## 📊 Comparaison

| Aspect | Actuel | Proposé | Gain |
|--------|--------|---------|------|
| **Fichiers config** | defaults.json + .env | .env uniquement | -1 fichier |
| **config.sh lignes** | 65 | 30 | -35 lignes |
| **spec-builder.sh lignes** | 105 | 50 | -55 lignes |
| **Total** | 170 lignes | 80 lignes | **-90 lignes (-53%)** |
| **Complexité** | Moyenne | Faible | ✅ |
| **Maintenabilité** | Moyenne | Haute | ✅ |

## 🎯 Recommandation

**✅ Appliquer cette optimisation** car :
- Réduction significative du code (-53%)
- Single source of truth
- Plus simple à comprendre et maintenir
- Plus flexible (chaque env a son .env complet)

