# Makefile for Druid Kafka ingestion

.PHONY: help compile validate deploy-dev deploy-staging deploy-prod rollback clean status logs check-deps install-deps init test-template list-schemas suspend resume reset restart tasks

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

check-deps: ## Check required dependencies
	@command -v protoc >/dev/null 2>&1 || { echo "ERROR: protoc missing"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "ERROR: jq missing"; exit 1; }
	@command -v envsubst >/dev/null 2>&1 || { echo "ERROR: envsubst missing"; exit 1; }
	@command -v curl >/dev/null 2>&1 || { echo "ERROR: curl missing"; exit 1; }

install-deps: ## Install dependencies (Ubuntu/Debian)
	@sudo apt-get update && sudo apt-get install -y protobuf-compiler jq gettext-base curl

compile: ## Compile Protobuf schemas
	@./scripts/compile-proto.sh

validate: ## Validate all JSON config files
	@jq empty config/dimensions.json || { echo "ERROR: Invalid JSON in config/dimensions.json"; exit 1; }
	@jq empty config/metrics.json || { echo "ERROR: Invalid JSON in config/metrics.json"; exit 1; }
	@jq empty config/transforms.json || { echo "ERROR: Invalid JSON in config/transforms.json"; exit 1; }
	@jq empty config/index-spec.json || { echo "ERROR: Invalid JSON in config/index-spec.json"; exit 1; }

test-template: ## Test template generation (usage: make test-template ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: Usage: make test-template ENV=<env>"; exit 1; }
	@source config/$(ENV).env && \
		export SCHEMA_VERSION="test-version" \
		DIMENSIONS_JSON=$$(jq -c . config/dimensions.json) \
		METRICS_JSON=$$(jq -c . config/metrics.json) \
		TRANSFORMS_JSON=$$(jq -c . config/transforms.json) \
		INDEX_SPEC_JSON=$$(jq -c . config/index-spec.json) && \
		mkdir -p druid-specs/generated && \
		envsubst < druid-specs/templates/kafka-supervisor.json > druid-specs/generated/test-output.json && \
		jq . druid-specs/generated/test-output.json | head -30

init: check-deps compile validate ## Initialize project (check deps, compile, validate)

deploy-dev: ## Deploy to DEV environment
	@./scripts/deploy-supervisor.sh dev

deploy-staging: ## Deploy to STAGING environment
	@./scripts/deploy-supervisor.sh staging

deploy-prod: ## Deploy to PROD environment
	@./scripts/deploy-supervisor.sh prod

rollback: ## Rollback schema (usage: make rollback ENV=prod VERSION=abc123f)
	@[ -n "$(ENV)" ] && [ -n "$(VERSION)" ] || { echo "ERROR: Usage: make rollback ENV=<env> VERSION=<version>"; exit 1; }
	@./scripts/rollback-schema.sh $(VERSION) $(ENV)

status: ## Get supervisor status (usage: make status ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: Usage: make status ENV=<env>"; exit 1; }
	@source config/$(ENV).env && curl -s $${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor/$${DATASOURCE_NAME}/status | jq .

logs: ## Get supervisor logs (usage: make logs ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: Usage: make logs ENV=<env>"; exit 1; }
	@source config/$(ENV).env && curl -s $${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor/$${DATASOURCE_NAME}/status | jq '.payload'

suspend: ## Suspend supervisor ingestion (usage: make suspend ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: Usage: make suspend ENV=<env>"; exit 1; }
	@source config/$(ENV).env && \
		echo "Suspending supervisor: $${DATASOURCE_NAME}" && \
		curl -s -X POST $${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor/$${DATASOURCE_NAME}/suspend | jq . || echo "Failed to suspend"

resume: ## Resume supervisor ingestion (usage: make resume ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: Usage: make resume ENV=<env>"; exit 1; }
	@source config/$(ENV).env && \
		echo "Resuming supervisor: $${DATASOURCE_NAME}" && \
		curl -s -X POST $${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor/$${DATASOURCE_NAME}/resume | jq . || echo "Failed to resume"

reset: ## Reset supervisor offsets (usage: make reset ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: Usage: make reset ENV=<env>"; exit 1; }
	@source config/$(ENV).env && \
		echo "WARNING: This will reset offsets for supervisor: $${DATASOURCE_NAME}" && \
		curl -s -X POST $${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor/$${DATASOURCE_NAME}/reset | jq . || echo "Failed to reset"

restart: ## Restart supervisor by redeploying (usage: make restart ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: Usage: make restart ENV=<env>"; exit 1; }
	@echo "Restarting supervisor for environment: $(ENV)"
	@case "$(ENV)" in \
		dev) make deploy-dev ;; \
		staging) make deploy-staging ;; \
		prod) make deploy-prod ;; \
		*) echo "ERROR: Invalid environment. Use dev, staging, or prod"; exit 1 ;; \
	esac

tasks: ## Get ingestion tasks status (usage: make tasks ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: Usage: make tasks ENV=<env>"; exit 1; }
	@source config/$(ENV).env && \
		echo "=== Ingestion Tasks Status for $${DATASOURCE_NAME} ===" && \
		curl -s $${DRUID_OVERLORD_URL}/druid/indexer/v1/tasks | \
		jq -r '[.[] | select(.dataSource == "'$${DATASOURCE_NAME}'")] | \
		"Total tasks: \(length)\n" + \
		(group_by(.statusCode) | map("\(.[0].statusCode): \(length)") | join("\n")) + \
		"\n\n=== Latest 5 Tasks ===" + \
		(sort_by(.createdTime) | reverse | .[0:5] | map("\nID: \(.id)\nStatus: \(.statusCode)\nCreated: \(.createdTime)\nDuration: \(.duration)ms") | join("\n---"))'

list-schemas: ## List schema versions on S3
	@[ -n "$(S3_BUCKET)" ] || { echo "ERROR: S3_BUCKET not set. Source config file first."; exit 1; }
	@aws s3 ls s3://$(S3_BUCKET)/schemas/ 2>/dev/null | grep "PRE" | awk '{print $$2}' || echo "No schemas found"

test-local: ## Setup local Docker Compose environment for testing
	@./scripts/test-local.sh

clean: ## Clean generated files
	@rm -rf schemas/compiled/ druid-specs/generated/ test-output.json
