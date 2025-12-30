#!/bin/bash
# scripts/rollback-schema.sh
# Script pour effectuer un rollback vers une version précédente du schéma

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function print_usage() {
    echo "Usage: $0 <schema_version> <environment>"
    echo ""
    echo "Arguments:"
    echo "  schema_version : Version du schéma à restaurer (commit SHA ou tag)"
    echo "  environment    : dev, staging, ou prod"
    echo ""
    echo "Exemples:"
    echo "  $0 abc123f dev"
    echo "  $0 stable prod"
    exit 1
}

if [ $# -ne 2 ]; then
    print_usage
fi

SCHEMA_VERSION=$1
ENVIRONMENT=$2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Valider l'environnement
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}❌ Environnement invalide: $ENVIRONMENT${NC}"
    exit 1
fi

echo -e "${YELLOW}🔄 Rollback du schéma Druid${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Version cible: ${BLUE}$SCHEMA_VERSION${NC}"
echo -e "Environnement: ${BLUE}$ENVIRONMENT${NC}"
echo ""

# Charger la configuration
CONFIG_FILE="$PROJECT_ROOT/config/${ENVIRONMENT}.env"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Configuration introuvable: $CONFIG_FILE${NC}"
    exit 1
fi

source "$CONFIG_FILE"

# Vérifier si le schéma existe sur S3
S3_BUCKET=${S3_BUCKET:-"my-company-druid-schemas"}
S3_PATH="s3://${S3_BUCKET}/schemas/${SCHEMA_VERSION}/"

echo -e "${BLUE}🔍 Vérification de l'existence du schéma sur S3...${NC}"
if ! aws s3 ls "$S3_PATH" &> /dev/null; then
    echo -e "${RED}❌ Schéma introuvable: $S3_PATH${NC}"
    echo ""
    echo "Versions disponibles:"
    aws s3 ls "s3://${S3_BUCKET}/schemas/" | grep "PRE" | awk '{print "  - " $2}'
    exit 1
fi

echo -e "${GREEN}✓${NC} Schéma trouvé sur S3"

# Lister les fichiers de cette version
echo ""
echo -e "${BLUE}Fichiers dans cette version:${NC}"
aws s3 ls "$S3_PATH"

echo ""
echo -e "${YELLOW}⚠️  ATTENTION: Cette opération va redéployer le superviseur${NC}"
if [ "$ENVIRONMENT" = "prod" ]; then
    echo -e "${RED}⚠️  Vous êtes sur le point de modifier la PRODUCTION${NC}"
fi

read -p "Continuer avec le rollback? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo -e "${YELLOW}Rollback annulé${NC}"
    exit 0
fi

# Utiliser le script de déploiement avec la version spécifique
echo -e "${BLUE}🚀 Déploiement de la version $SCHEMA_VERSION...${NC}"
"$SCRIPT_DIR/deploy-supervisor.sh" "$ENVIRONMENT" "$SCHEMA_VERSION"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Rollback terminé avec succès${NC}"
    echo -e "Le superviseur utilise maintenant la version: ${BLUE}$SCHEMA_VERSION${NC}"
else
    echo -e "${RED}❌ Échec du rollback${NC}"
    exit 1
fi
