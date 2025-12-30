# Makefile pour l'ingestion Druid depuis Kafka
# Utilise envsubst (natif) au lieu de Jinja2

.PHONY: help compile validate deploy-dev deploy-staging deploy-prod rollback clean status logs

help: ## Affiche cette aide
	@echo "Commandes disponibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

compile: ## Compile les schémas Protobuf en descriptors
	@echo "🔧 Compilation des schémas Protobuf..."
	@./scripts/compile-proto.sh

validate: ## Valide la configuration JSON
	@echo "🧪 Validation des fichiers de configuration..."
	@jq empty config/dimensions.json
	@echo "✅ dimensions.json valide ($(shell jq '. | length' config/dimensions.json) dimensions)"

deploy-dev: ## Déploie en environnement DEV
	@echo "🚀 Déploiement en DEV..."
	@./scripts/deploy-supervisor.sh dev

deploy-staging: ## Déploie en environnement STAGING
	@echo "🚀 Déploiement en STAGING..."
	@./scripts/deploy-supervisor.sh staging

deploy-prod: ## Déploie en environnement PRODUCTION
	@echo "🚀 Déploiement en PRODUCTION..."
	@./scripts/deploy-supervisor.sh prod

rollback: ## Rollback vers une version précédente (usage: make rollback ENV=prod VERSION=abc123f)
	@if [ -z "$(ENV)" ] || [ -z "$(VERSION)" ]; then \
		echo "❌ Usage: make rollback ENV=<env> VERSION=<version>"; \
		echo "   Exemple: make rollback ENV=prod VERSION=abc123f"; \
		exit 1; \
	fi
	@./scripts/rollback-schema.sh $(VERSION) $(ENV)

clean: ## Nettoie les fichiers générés
	@echo "🧹 Nettoyage..."
	@rm -rf schemas/compiled/
	@rm -f supervisor-spec*.json
	@echo "✅ Nettoyage terminé"

check-deps: ## Vérifie que les dépendances sont installées
	@echo "🔍 Vérification des dépendances..."
	@command -v protoc >/dev/null 2>&1 || { echo "❌ protoc non installé"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "❌ jq non installé"; exit 1; }
	@command -v envsubst >/dev/null 2>&1 || { echo "❌ envsubst non installé (gettext-base)"; exit 1; }
	@command -v curl >/dev/null 2>&1 || { echo "❌ curl non installé"; exit 1; }
	@command -v aws >/dev/null 2>&1 || { echo "⚠️  aws-cli non installé (optionnel)"; }
	@echo "✅ Toutes les dépendances requises sont installées"

status: ## Affiche le statut du superviseur (usage: make status ENV=dev)
	@if [ -z "$(ENV)" ]; then \
		echo "❌ Usage: make status ENV=<env>"; \
		exit 1; \
	fi
	@source config/$(ENV).env && \
		curl -s $${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor/$${DATASOURCE_NAME}/status | jq .

logs: ## Affiche les logs du superviseur (usage: make logs ENV=dev)
	@if [ -z "$(ENV)" ]; then \
		echo "❌ Usage: make logs ENV=<env>"; \
		exit 1; \
	fi
	@source config/$(ENV).env && \
		echo "📋 Logs pour $${DATASOURCE_NAME}:" && \
		curl -s $${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor/$${DATASOURCE_NAME}/status | \
		jq '.payload'

list-schemas: ## Liste les versions de schémas disponibles sur S3
	@echo "📦 Versions de schémas sur S3:"
	@aws s3 ls s3://my-company-druid-schemas/schemas/ | grep "PRE" | awk '{print "  - " $$2}'

test-template: ## Teste la génération du template localement (usage: make test-template ENV=dev)
	@if [ -z "$(ENV)" ]; then \
		echo "❌ Usage: make test-template ENV=<env>"; \
		exit 1; \
	fi
	@echo "🧪 Test de génération du template pour $(ENV)..."
	@source config/$(ENV).env && \
		export SCHEMA_VERSION="test-version" && \
		export DIMENSIONS_JSON=$$(jq -c . config/dimensions.json) && \
		envsubst < druid-specs/templates/kafka-supervisor.json > test-output.json && \
		jq . test-output.json > /dev/null && \
		echo "✅ Template généré avec succès: test-output.json" && \
		echo "📄 Aperçu:" && \
		jq . test-output.json | head -30

init: check-deps compile validate ## Initialise le projet (vérifie deps, compile, teste)
	@echo "✅ Projet initialisé avec succès!"

install-deps-ubuntu: ## Installe les dépendances sur Ubuntu/Debian
	@echo "📦 Installation des dépendances Ubuntu/Debian..."
	@sudo apt-get update
	@sudo apt-get install -y protobuf-compiler jq gettext-base curl
	@echo "✅ Dépendances installées"

install-deps-macos: ## Installe les dépendances sur macOS
	@echo "📦 Installation des dépendances macOS..."
	@brew install protobuf jq gettext curl
	@echo "✅ Dépendances installées"
