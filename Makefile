.PHONY: help

help: ## Show help
	@echo "Available commands:"
	@echo "  make druid-<command>  - Run command in druid-ingestion module"
	@echo ""
	@echo "Examples:"
	@echo "  make druid-help       - Show druid-ingestion commands"
	@echo "  make druid-deploy-dev - Deploy to dev"
	@echo ""
	@cd druid-ingestion && $(MAKE) help

%:
	@cd druid-ingestion && $(MAKE) $*