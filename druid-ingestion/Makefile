.PHONY: help compile validate deploy-dev deploy-staging deploy-prod rollback clean status logs check-deps install-deps init test-template list-schemas suspend resume reset restart tasks test-local

help: ## Show help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

check-deps: ## Check dependencies
	@for cmd in protoc jq envsubst curl; do \
		command -v $$cmd >/dev/null 2>&1 || { echo "ERROR: $$cmd missing"; exit 1; }; \
	done

install-deps: ## Install dependencies (Ubuntu/Debian)
	@sudo apt-get update && sudo apt-get install -y protobuf-compiler jq gettext-base curl

compile: ## Compile Protobuf schemas
	@./scripts/compile-proto.sh

validate: ## Validate JSON configs
	@for f in dimensions metrics transforms index-spec; do \
		jq empty config/$$f.json || { echo "ERROR: Invalid JSON: config/$$f.json"; exit 1; }; \
	done

test-template: ## Test template generation (ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: ENV required"; exit 1; }
	@./scripts/deploy-supervisor.sh $(ENV) test-version 2>&1 | grep -v "^Deploying" | grep -v "^Generated" || true
	@echo "\n=== Generated supervisor spec ==="
	@jq . druid-specs/generated/supervisor-spec-$(ENV).json | head -40

init: check-deps compile validate ## Initialize project

deploy-dev: ## Deploy to dev
	@./scripts/deploy-supervisor.sh dev

deploy-staging: ## Deploy to staging
	@./scripts/deploy-supervisor.sh staging

deploy-prod: ## Deploy to prod
	@./scripts/deploy-supervisor.sh prod

rollback: ## Rollback schema (ENV=prod VERSION=abc123f)
	@[ -n "$(ENV)" ] && [ -n "$(VERSION)" ] || { echo "ERROR: ENV and VERSION required"; exit 1; }
	@./scripts/rollback-schema.sh $(VERSION) $(ENV)

status: ## Get supervisor status (ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: ENV required"; exit 1; }
	@source config/$(ENV).env && \
		curl -s $${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor/$${DATASOURCE_NAME}/status | jq .

logs: ## Get supervisor logs (ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: ENV required"; exit 1; }
	@source config/$(ENV).env && \
		curl -s $${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor/$${DATASOURCE_NAME}/status | jq '.payload'

suspend: ## Suspend supervisor (ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: ENV required"; exit 1; }
	@source config/$(ENV).env && \
		curl -s -X POST $${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor/$${DATASOURCE_NAME}/suspend | jq .

resume: ## Resume supervisor (ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: ENV required"; exit 1; }
	@source config/$(ENV).env && \
		curl -s -X POST $${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor/$${DATASOURCE_NAME}/resume | jq .

reset: ## Reset supervisor offsets (ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: ENV required"; exit 1; }
	@source config/$(ENV).env && \
		curl -s -X POST $${DRUID_OVERLORD_URL}/druid/indexer/v1/supervisor/$${DATASOURCE_NAME}/reset | jq .

restart: ## Restart supervisor (ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: ENV required"; exit 1; }
	@make deploy-$(ENV)

tasks: ## Get tasks status (ENV=dev)
	@[ -n "$(ENV)" ] || { echo "ERROR: ENV required"; exit 1; }
	@source config/$(ENV).env && \
		curl -s $${DRUID_OVERLORD_URL}/druid/indexer/v1/tasks | \
		jq -r '[.[] | select(.dataSource == "'$${DATASOURCE_NAME}'")] | \
		"Total: \(length)\n" + \
		(group_by(.statusCode) | map("\(.[0].statusCode): \(length)") | join("\n")) + \
		"\n\nLatest 5:\n" + \
		(sort_by(.createdTime) | reverse | .[0:5] | map("\(.id) [\(.statusCode)] \(.createdTime)") | join("\n"))'

list-schemas: ## List S3 schema versions
	@[ -n "$(S3_BUCKET)" ] || { echo "ERROR: S3_BUCKET required"; exit 1; }
	@aws s3 ls s3://$(S3_BUCKET)/schemas/ 2>/dev/null | grep "PRE" | awk '{print $$2}' || echo "None"

test-local: ## Setup local Docker environment
	@./scripts/test-local.sh

clean: ## Clean generated files
	@rm -rf schemas/compiled/ druid-specs/generated/ test-output.json
