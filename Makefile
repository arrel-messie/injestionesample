    # Makefile pour l'ingestion Druid depuis Kafka

    .PHONY: help compile validate deploy-dev deploy-staging deploy-prod rollback clean status logs

    help:
        @grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

    compile: ## Compile les schémas Protobuf
        @./scripts/compile-proto.sh

    validate: ## Valide la config JSON
        @jq empty config/dimensions.json

    deploy-dev: ## Deploy en DEV
        @./scripts/deploy-supervisor.sh dev

    deploy-staging: ## Deploy en STAGING
        @./scripts/deploy-supervisor.sh staging

    deploy-prod: ## Deploy en PROD
        @./scripts/deploy-supervisor.sh prod

    rollback: ## Rollback (make rollback ENV=prod VERSION=abc123f)
        @[ -n "$(ENV)" ] && [ -n "$(VERSION)" ] || { echo "Usage: make rollback ENV=<env> VERSION=<version>"; exit 1; }
        @./scripts/rollback-schema.sh $(VERSION) $(ENV)

    clean: ## Nettoie les fichiers générés
        @rm -rf schemas/compiled/ supervisor-spec*.json

    check-deps: ## Vérifie les dépendances
        @command -v protoc >/dev/null 2>&1 || { echo "protoc missing"; exit 1; }
        @command -v jq >/dev/null 2>&1 || { echo "jq missing"; exit 1; }
        @command -v envsubst >/dev/null 2>&1 || { echo "envsubst missing"; exit 1; }
        @command -v curl >/dev/null 2>&1 || { echo "curl missing"; exit 1; }

    status: ## Status du superviseur (make status ENV=dev)
        @[ -n "$(ENV)" ] || { echo "Usage: make status ENV=<env>"; exit 1; }
        @source config/$(ENV).env && curl -s $${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor/$${DATASOURCE_NAME}/status | jq .

    logs: ## Logs du superviseur (make logs ENV=dev)
        @[ -n "$(ENV)" ] || { echo "Usage: make logs ENV=<env>"; exit 1; }
        @source config/$(ENV).env && curl -s $${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor/$${DATASOURCE_NAME}/status | jq '.payload'

    list-schemas: ## Liste les versions sur S3
        @aws s3 ls s3://my-company-druid-schemas/schemas/ | grep "PRE" | awk '{print $$2}'

    test-template: ## Teste le template (make test-template ENV=dev)
        @[ -n "$(ENV)" ] || { echo "Usage: make test-template ENV=<env>"; exit 1; }
        @source config/$(ENV).env && \
            export SCHEMA_VERSION="test-version" DIMENSIONS_JSON=$$(jq -c . config/dimensions.json) && \
            envsubst < druid-specs/templates/kafka-supervisor.json > test-output.json && \
            jq . test-output.json | head -30

    init: check-deps compile validate ## Init projet

    install-deps: ## Install dépendances
        @sudo apt-get update && sudo apt-get install -y protobuf-compiler jq gettext-base curl