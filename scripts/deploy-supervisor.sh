#!/bin/bash
# scripts/deploy-supervisor.sh
# Script pour déployer manuellement un superviseur Druid avec envsubst

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Couleurs pour l'output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function print_usage() {
    echo "Usage: $0 <environment> [schema_version]"
    echo ""
    echo "Arguments:"
    echo "  environment     : dev, staging, ou prod"
    echo "  schema_version  : Version du schéma S3 (optionnel, défaut: latest)"
    echo ""
    echo "Exemples:"
    echo "  $0 dev"
    echo "  $0 prod abc123f"
    exit 1
}

# Vérifier les arguments
if [ $# -lt 1 ]; then
    print_usage
fi

ENVIRONMENT=$1
SCHEMA_VERSION=${2:-"${ENVIRONMENT}-latest"}

# Valider l'environnement
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}❌ Environnement invalide: $ENVIRONMENT${NC}"
    echo "Valeurs acceptées: dev, staging, prod"
    exit 1
fi

echo -e "${BLUE}🚀 Déploiement Druid Supervisor${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Environnement: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "Version schéma: ${YELLOW}$SCHEMA_VERSION${NC}"
echo ""

# Vérifier les dépendances
if ! command -v envsubst &> /dev/null; then
    echo -e "${RED}❌ envsubst n'est pas installé${NC}"
    echo "Installation: apt-get install gettext-base (Ubuntu/Debian)"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq n'est pas installé${NC}"
    echo "Installation: apt-get install jq (Ubuntu/Debian)"
    exit 1
fi

# Charger la configuration de l'environnement
CONFIG_FILE="$PROJECT_ROOT/config/${ENVIRONMENT}.env"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Fichier de configuration introuvable: $CONFIG_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Chargement de la configuration..."
source "$CONFIG_FILE"

# Charger les dimensions
DIMENSIONS_FILE="$PROJECT_ROOT/config/dimensions.json"
if [ ! -f "$DIMENSIONS_FILE" ]; then
    echo -e "${RED}❌ Fichier dimensions.json introuvable${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Chargement des dimensions..."
export DIMENSIONS_JSON=$(jq -c . "$DIMENSIONS_FILE")

# Générer la spec
TEMPLATE_FILE="$PROJECT_ROOT/druid-specs/templates/kafka-supervisor.json"
OUTPUT_FILE="$PROJECT_ROOT/supervisor-spec-${ENVIRONMENT}.json"

echo -e "${GREEN}✓${NC} Génération de la spec Druid avec envsubst..."

envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

# Valider le JSON
echo -e "${GREEN}✓${NC} Validation du JSON..."
if ! jq empty "$OUTPUT_FILE" 2>/dev/null; then
    echo -e "${RED}❌ JSON invalide généré${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Spec générée: $OUTPUT_FILE"
echo ""

# Afficher un aperçu
echo -e "${BLUE}📄 Aperçu de la configuration:${NC}"
echo -e "   Datasource: ${YELLOW}$(jq -r '.spec.dataSchema.dataSource' "$OUTPUT_FILE")${NC}"
echo -e "   Topic Kafka: ${YELLOW}$(jq -r '.spec.ioConfig.topic' "$OUTPUT_FILE")${NC}"
echo -e "   Tasks: ${YELLOW}$(jq -r '.spec.ioConfig.taskCount' "$OUTPUT_FILE")${NC}"
echo -e "   Replicas: ${YELLOW}$(jq -r '.spec.ioConfig.replicas' "$OUTPUT_FILE")${NC}"
echo ""

# Demander confirmation pour la production
if [ "$ENVIRONMENT" = "prod" ]; then
    echo -e "${YELLOW}⚠️  ATTENTION: Vous êtes sur le point de déployer en PRODUCTION${NC}"
    read -p "Êtes-vous sûr de vouloir continuer? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        echo -e "${YELLOW}Déploiement annulé${NC}"
        exit 0
    fi
fi

# Déployer vers Druid
echo -e "${BLUE}🚀 Déploiement vers Druid...${NC}"
response=$(curl -s -w "\n%{http_code}" -X POST \
    -H 'Content-Type: application/json' \
    -d @"$OUTPUT_FILE" \
    "${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

echo "HTTP Status: $http_code"

if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    echo -e "${GREEN}✅ Déploiement réussi!${NC}"
    echo ""
    echo -e "${BLUE}Response:${NC}"
    echo "$body" | jq . 2>/dev/null || echo "$body"
    echo ""
    echo -e "${GREEN}Le superviseur est maintenant actif${NC}"
    echo -e "Console Druid: ${DRUID_OVERLORD_URL}/unified-console.html#supervisors"
else
    echo -e "${RED}❌ Échec du déploiement${NC}"
    echo ""
    echo -e "${RED}Response:${NC}"
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
fi
