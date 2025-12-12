.PHONY: setup-deploy help

DEPLOY_CONFIG := .deploy-config

help:
	@echo "Available commands:"
	@echo "  make setup-deploy  - Configure cloud provider for deployment"
	@echo "  make help          - Show this help message"

setup-deploy:
	@echo "=== Deployment Setup ==="
	@echo ""
	@echo "Select your cloud provider:"
	@echo "  1) AWS"
	@echo "  2) GCP"
	@echo "  3) Azure"
	@echo ""
	@read -p "Enter choice [1-3]: " choice; \
	case $$choice in \
		1) provider="aws";; \
		2) provider="gcp";; \
		3) provider="azure";; \
		*) echo "Invalid choice"; exit 1;; \
	esac; \
	echo "CLOUD_PROVIDER=$$provider" > $(DEPLOY_CONFIG); \
	echo ""; \
	echo "✓ Cloud provider set to: $$provider"; \
	echo "✓ Configuration saved to $(DEPLOY_CONFIG)"
