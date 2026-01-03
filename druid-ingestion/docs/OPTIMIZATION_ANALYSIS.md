# Analyse d'Optimisation - Réduction du Volume de Code

## 📊 État Actuel

**Total: 330 lignes**
- `druid-ingestion.sh`: 158 lignes
- `lib/config.sh`: 65 lignes
- `lib/spec-builder.sh`: 107 lignes

## 🔍 Problèmes Identifiés

### 1. **Fichier `logger.sh` manquant** (CRITIQUE)
- `config.sh` ligne 6: `source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"`
- `spec-builder.sh` ligne 6: `source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"`
- **Impact**: Scripts ne fonctionnent pas si `logger.sh` n'existe pas
- **Solution**: Intégrer les fonctions de logging directement ou créer le fichier

### 2. **Redondance dans `parse_opts()`**
- Retourne plusieurs valeurs via `echo` mais utilisation avec tableau
- Ordre non garanti, fragile
- **Lignes concernées**: `druid-ingestion.sh:29-42`
- **Gain potentiel**: 5-10 lignes

### 3. **Variables hardcodées dans `_export_template_vars()`**
- 30+ variables hardcodées dans `spec-builder.sh:48-63`
- Ces valeurs existent déjà dans `defaults.json`
- **Gain potentiel**: 20-30 lignes

### 4. **Appels `jq` multiples dans `_load_index_spec()`**
- 4 appels `jq` séparés pour charger l'index spec
- Pourrait être un seul appel avec un objet
- **Gain potentiel**: 3-5 lignes

### 5. **Pattern répétitif dans les commandes `cmd_*`**
- Toutes les commandes font: `parse_opts`, `load_config`, validation
- **Gain potentiel**: 10-15 lignes avec une fonction wrapper

### 6. **Fonction `http_request()` complexe**
- Logique de retry répétitive
- **Gain potentiel**: 5-10 lignes

### 7. **Template JSON avec trop de variables**
- Le template utilise `envsubst` avec 30+ variables
- Ces valeurs pourraient être injectées directement depuis `defaults.json`
- **Gain potentiel**: Simplification majeure

### 8. **Validation répétitive**
- `[ -z "${opts[0]:-}" ] && error_exit "Environment (-e) is required"` répété 3x
- **Gain potentiel**: 6 lignes

## 🎯 Propositions d'Optimisation

### Priorité HAUTE

#### 1. **Créer `lib/logger.sh` ou intégrer directement**
```bash
# Option A: Créer lib/logger.sh (3 lignes)
log_info() { echo -e "\033[0;32m[INFO]\033[0m $*" >&2; }
log_warn() { echo -e "\033[1;33m[WARN]\033[0m $*" >&2; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }

# Option B: Intégrer dans druid-ingestion.sh (déjà fait)
# Gain: 0 lignes (déjà intégré)
```

#### 2. **Simplifier `_export_template_vars()` avec `defaults.json`**
```bash
# Avant: 20 lignes de variables hardcodées
# Après: 5 lignes en lisant defaults.json
_export_template_vars() {
    local defaults_file="${1:-}"
    [ ! -f "$defaults_file" ] && return
    # Export toutes les valeurs depuis defaults.json
    jq -r '.kafka, .task, .tuning | to_entries[] | "\(.key | ascii_upcase | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)") | gsub("(?<x>[a-z])(?<y>[A-Z])"; "\(.x)_\(.y)"))=\"\(.value)\""' "$defaults_file" | while IFS='=' read -r key value; do
        export "KAFKA_${key}"="$value"
    done
}
```
**Gain estimé**: 15-20 lignes

#### 3. **Consolider `_load_index_spec()`**
```bash
# Avant: 4 appels jq
# Après: 1 appel jq
_load_index_spec() {
    local schema_file="$1"
    eval "$(jq -r '.indexSpec | to_entries[] | "export INDEX_SPEC_\(.key | ascii_upcase)=\"\(.value)\""' "$schema_file")"
}
```
**Gain estimé**: 3 lignes

#### 4. **Fonction wrapper pour commandes nécessitant env**
```bash
# Wrapper générique
with_env() {
    local cmd="$1" env="${2:-}"
    [ -z "$env" ] && error_exit "Environment (-e) is required"
    load_config "$env" "$CONFIG_DIR" || return 1
    shift 2
    "$cmd" "$env" "$@"
}

# Utilisation
cmd_deploy() {
    local opts=($(parse_opts "$@"))
    with_env _deploy_impl "${opts[0]}" || return 1
}
```
**Gain estimé**: 10-15 lignes

### Priorité MOYENNE

#### 5. **Simplifier `parse_opts()` avec variables nommées**
```bash
# Utiliser des variables nommées au lieu d'un tableau
parse_opts() {
    local env="" output="" file=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -e|--env) env="$2"; shift 2 ;;
            -o|--output) output="$2"; shift 2 ;;
            -f|--file) file="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    # Retourner via variables globales ou eval
    PARSED_ENV="$env"
    PARSED_OUTPUT="$output"
    PARSED_FILE="$file"
}
```
**Gain estimé**: 5 lignes

#### 6. **Simplifier `http_request()`**
```bash
# Version plus concise
http_request() {
    local method="$1" url="$2" data_file="${3:-}" attempt=0 max_retries="${4:-3}"
    local curl_opts=(-s -w "\n%{http_code}" -X "$method")
    [ -n "$data_file" ] && [ -f "$data_file" ] && curl_opts+=(-H "Content-Type: application/json" -d @"$data_file") || curl_opts+=(-H "Accept: application/json")
    
    while [ $attempt -lt $max_retries ]; do
        local response=$(curl "${curl_opts[@]}" "$url" 2>&1) || { [ $((++attempt)) -lt $max_retries ] && sleep $((attempt * 2)) && continue || return 1; }
        local http_code=$(echo "$response" | tail -n1)
        local response_body=$(echo "$response" | sed '$d')
        [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ] && echo "$response_body" && return 0
        [ "$http_code" -ge 400 ] && [ "$http_code" -lt 500 ] && log_error "HTTP $http_code: $response_body" && return 1
        [ $((++attempt)) -lt $max_retries ] && sleep $((attempt * 2))
    done
    error_exit "HTTP request failed after $max_retries attempts"
}
```
**Gain estimé**: 5 lignes

#### 7. **Générer template variables depuis `defaults.json`**
Au lieu de 30+ variables d'environnement, générer directement depuis JSON:
```bash
# Injecter defaults.json directement dans le template
build_spec() {
    # ... existing code ...
    # Au lieu de _export_template_vars, utiliser jq pour injecter
    jq --argfile defaults "$defaults_file" '. as $template | $defaults | ...' "$template_file" > "$output"
}
```
**Gain estimé**: 20-30 lignes (élimine `_export_template_vars`)

### Priorité BASSE

#### 8. **Consolider les fonctions de build spec**
Les 3 fonctions `_build_dimensions_spec`, `_build_metrics_spec`, `_build_transforms_spec` pourraient être une seule fonction générique.
**Gain estimé**: 5 lignes

#### 9. **Simplifier `usage()`**
Réduire la verbosité du message d'aide.
**Gain estimé**: 5 lignes

## 📈 Gains Estimés Totaux

| Optimisation | Gain (lignes) | Priorité | Complexité |
|--------------|---------------|----------|------------|
| 1. Logger intégré | 0 | HAUTE | Faible |
| 2. `_export_template_vars()` depuis JSON | 15-20 | HAUTE | Moyenne |
| 3. `_load_index_spec()` consolidé | 3 | HAUTE | Faible |
| 4. Wrapper `with_env()` | 10-15 | HAUTE | Faible |
| 5. `parse_opts()` amélioré | 5 | MOYENNE | Faible |
| 6. `http_request()` simplifié | 5 | MOYENNE | Faible |
| 7. Template depuis JSON | 20-30 | MOYENNE | Élevée |
| 8. Build spec consolidé | 5 | BASSE | Faible |
| 9. `usage()` simplifié | 5 | BASSE | Faible |

**Total estimé**: 68-100 lignes (20-30% de réduction)

## 🎯 Recommandations

### Phase 1 (Gain immédiat: ~40 lignes)
1. ✅ Créer `lib/logger.sh` ou vérifier que les fonctions sont définies
2. ✅ Consolider `_load_index_spec()` (1 appel jq)
3. ✅ Wrapper `with_env()` pour commandes
4. ✅ Simplifier `parse_opts()` avec validation centralisée

### Phase 2 (Gain moyen: ~30 lignes)
5. ✅ Simplifier `_export_template_vars()` en lisant depuis `defaults.json`
6. ✅ Simplifier `http_request()`

### Phase 3 (Gain avancé: ~30 lignes, complexité élevée)
7. ⚠️ Générer template directement depuis JSON (nécessite refactoring du template)

## ⚠️ Risques

1. **Génération template depuis JSON**: Risque de casser la compatibilité avec `envsubst`
2. **Simplification excessive**: Peut rendre le code moins lisible
3. **Dépendances jq**: Plus de dépendance sur `jq` pour certaines opérations

## ✅ Critères de Succès

- Réduction de 20-30% du volume de code
- Maintenir la lisibilité
- Pas de régression fonctionnelle
- Tests passent toujours

