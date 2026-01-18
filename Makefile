.PHONY: setup-dev setup-staging setup-deploy help test-setup

DEV_CONFIG := .dev-config
STAGING_CONFIG := .staging-config
DEPLOY_CONFIG := .deploy-config

# Default values (can be overridden via command line or environment)
AI_PROVIDER ?=
AI_API_KEY ?=
AI_MODEL ?=
AI_URL ?=
CLOUD_PROVIDER ?=

# PostgreSQL superuser
POSTGRES_PASSWORD ?=

# Database connection defaults
DB_APP_HOST ?= postgres
DB_APP_PORT ?= 5432
DB_APP_NAME ?= keystone_db
DB_APP_SCHEMA ?= app

DB_KEYCLOAK_HOST ?= postgres
DB_KEYCLOAK_PORT ?= 5432
DB_KEYCLOAK_NAME ?= keystone_db
DB_KEYCLOAK_SCHEMA ?= keycloak

# Database users
DB_MIGRATION_USER ?= migration
DB_MIGRATION_PASSWORD ?=
DB_APP_USER ?= appuser
DB_APP_PASSWORD ?=
DB_KEYCLOAK_USER ?= keycloak
DB_KEYCLOAK_PASSWORD ?=

# Keycloak admin
KEYCLOAK_ADMIN ?=
KEYCLOAK_ADMIN_PASSWORD ?=
CADDY_BUCKET_NAME ?=

# Azure specific
AZURE_SUBSCRIPTION_ID ?=
AZURE_PERMANENT_RG ?=
AZURE_PUBLIC_IP_NAME ?=
AZURE_STORAGE_ACCOUNT ?=
AZURE_STORAGE_CONTAINER ?=

help:
	@echo "Available commands:"
	@echo ""
	@echo "Setup commands:"
	@echo "  make setup-dev     - Configure local development environment"
	@echo "  make setup-staging - Configure staging environment (cloud)"
	@echo "  make setup-deploy  - Configure production environment (cloud)"
	@echo "  make test-setup    - Run automated tests for setup commands"
	@echo ""
	@echo "Docker commands (dev):"
	@echo "  make dev-up            - Start development environment"
	@echo "  make dev-down          - Stop development environment"
	@echo "  make dev-logs          - Show container logs"
	@echo "  make dev-ps            - Show container status"
	@echo "  make dev-clean         - Remove all data and volumes"
	@echo "  make db-migrate        - Run database migrations"
	@echo "  make reindex-documents - Reindex all documents (after provider change)"
	@echo ""
	@echo "Frontend commands:"
	@echo "  make frontend         - Start frontend development server"
	@echo "  make frontend-install - Install frontend dependencies"
	@echo "  make frontend-env     - Generate frontend/.env.local"
	@echo ""
	@echo "Infrastructure commands (cloud):"
	@echo "  make infra-init    - Initialize OpenTofu"
	@echo "  make infra-plan    - Preview infrastructure changes"
	@echo "  make infra-apply   - Deploy infrastructure"
	@echo "  make infra-destroy - Destroy infrastructure"
	@echo "  make infra-output  - Show infrastructure outputs"
	@echo ""
	@echo "Non-interactive mode (examples):"
	@echo "  make setup-dev AI_PROVIDER=openai AI_API_KEY=sk-xxx"
	@echo "  make setup-deploy CLOUD_PROVIDER=azure AI_PROVIDER=openai ..."
	@echo "  make dev-logs      - Show container logs"
	@echo "  make dev-ps        - Show container status"
	@echo "  make dev-clean     - Remove all data and volumes"
	@echo ""
	@echo "Non-interactive mode (example):"
	@echo "  make setup-dev AI_PROVIDER=openai AI_API_KEY=sk-xxx"

# ============================================================
# Helper function to write database config
# ============================================================
define write_db_config
	echo "" >> $(1); \
	echo "# Application Database" >> $(1); \
	echo "DB_APP_HOST=$(2)" >> $(1); \
	echo "DB_APP_PORT=$(3)" >> $(1); \
	echo "DB_APP_NAME=$(4)" >> $(1); \
	echo "DB_APP_SCHEMA=$(5)" >> $(1); \
	echo "DB_APP_USER=$(6)" >> $(1); \
	echo "DB_APP_PASSWORD=$(7)" >> $(1); \
	echo "" >> $(1); \
	echo "# Migration User" >> $(1); \
	echo "DB_MIGRATION_USER=$(8)" >> $(1); \
	echo "DB_MIGRATION_PASSWORD=$(9)" >> $(1); \
	echo "" >> $(1); \
	echo "# Keycloak Database" >> $(1); \
	echo "DB_KEYCLOAK_HOST=$(10)" >> $(1); \
	echo "DB_KEYCLOAK_PORT=$(11)" >> $(1); \
	echo "DB_KEYCLOAK_NAME=$(12)" >> $(1); \
	echo "DB_KEYCLOAK_SCHEMA=$(13)" >> $(1); \
	echo "DB_KEYCLOAK_USER=$(14)" >> $(1); \
	echo "DB_KEYCLOAK_PASSWORD=$(15)" >> $(1);
endef

# ============================================================
# SETUP DEV - Local Docker, default credentials
# ============================================================
setup-dev:
	@if [ -z "$(AI_PROVIDER)" ]; then \
		echo "╔════════════════════════════════════════╗"; \
		echo "║      Development Setup (Local)         ║"; \
		echo "╚════════════════════════════════════════╝"; \
		echo ""; \
		echo "┌─ AI Provider ──────────────────────────────"; \
		echo "│  1) OpenAI"; \
		echo "│  2) Gemini (Google)"; \
		echo "│  3) Anthropic"; \
		echo "│  4) Mistral"; \
		echo "│  5) Ollama (local)"; \
		echo "│  6) LM Studio (local)"; \
		echo "└──────────────────────────────────────────"; \
		read -p "Enter choice [1-6]: " ai_choice; \
		case $$ai_choice in \
			1) ai_provider="openai"; ai_key_name="OPENAI_API_KEY";; \
			2) ai_provider="gemini"; ai_key_name="GOOGLE_API_KEY";; \
			3) ai_provider="anthropic"; ai_key_name="ANTHROPIC_API_KEY";; \
			4) ai_provider="mistral"; ai_key_name="MISTRAL_API_KEY";; \
			5) ai_provider="ollama"; ai_key_name="";; \
			6) ai_provider="lmstudio"; ai_key_name="";; \
			*) echo "[FAIL] Invalid choice"; exit 1;; \
		esac; \
		ai_api_key=""; \
		ai_url=""; \
		if [ -n "$$ai_key_name" ]; then \
			echo ""; \
			read -s -p "Enter $$ai_key_name: " ai_api_key; \
			echo ""; \
		else \
			if [ "$$ai_provider" = "ollama" ]; then \
				default_url="http://host.docker.internal:11434"; \
				default_model="llama3.2"; \
			else \
				default_url="http://host.docker.internal:1234"; \
				default_model="local-model"; \
			fi; \
			echo ""; \
			read -p "Enter $$ai_provider URL [$$default_url]: " ai_url; \
			ai_url=$${ai_url:-$$default_url}; \
			read -p "Enter model name [$$default_model]: " ai_model; \
			ai_model=$${ai_model:-$$default_model}; \
		fi; \
	else \
		ai_provider="$(AI_PROVIDER)"; \
		ai_api_key="$(AI_API_KEY)"; \
		ai_model="$(AI_MODEL)"; \
		ai_url="$(AI_URL)"; \
		case $$ai_provider in \
			openai) ai_key_name="OPENAI_API_KEY";; \
			gemini) ai_key_name="GOOGLE_API_KEY";; \
			anthropic) ai_key_name="ANTHROPIC_API_KEY";; \
			mistral) ai_key_name="MISTRAL_API_KEY";; \
			ollama|lmstudio) ai_key_name="";; \
			*) echo "[FAIL] Invalid AI_PROVIDER: $$ai_provider"; exit 1;; \
		esac; \
		if [ -z "$$ai_key_name" ] && [ -z "$$ai_url" ]; then \
			if [ "$$ai_provider" = "ollama" ]; then \
				ai_url="http://host.docker.internal:11434"; \
			else \
				ai_url="http://host.docker.internal:1234"; \
			fi; \
		fi; \
	fi; \
	\
	echo "# Auto-generated by make setup-dev" > $(DEV_CONFIG); \
	echo "" >> $(DEV_CONFIG); \
	echo "# Environment" >> $(DEV_CONFIG); \
	echo "ENVIRONMENT=dev" >> $(DEV_CONFIG); \
	echo "" >> $(DEV_CONFIG); \
	echo "# AI Provider" >> $(DEV_CONFIG); \
	echo "AI_PROVIDER=$$ai_provider" >> $(DEV_CONFIG); \
	if [ -n "$$ai_key_name" ] && [ -n "$$ai_api_key" ]; then \
		echo "$$ai_key_name=$$ai_api_key" >> $(DEV_CONFIG); \
	fi; \
	if [ -n "$$ai_url" ]; then \
		echo "AI_URL=$$ai_url" >> $(DEV_CONFIG); \
	fi; \
	if [ -n "$$ai_model" ]; then \
		echo "AI_MODEL=$$ai_model" >> $(DEV_CONFIG); \
	fi; \
	echo "" >> $(DEV_CONFIG); \
	echo "# PostgreSQL Superuser" >> $(DEV_CONFIG); \
	echo "POSTGRES_PASSWORD=postgres" >> $(DEV_CONFIG); \
	echo "" >> $(DEV_CONFIG); \
	echo "# Application Database" >> $(DEV_CONFIG); \
	echo "DB_APP_HOST=postgres" >> $(DEV_CONFIG); \
	echo "DB_APP_PORT=5432" >> $(DEV_CONFIG); \
	echo "DB_APP_NAME=keystone_db" >> $(DEV_CONFIG); \
	echo "DB_APP_SCHEMA=app" >> $(DEV_CONFIG); \
	echo "DB_APP_USER=appuser" >> $(DEV_CONFIG); \
	echo "DB_APP_PASSWORD=appuser" >> $(DEV_CONFIG); \
	echo "" >> $(DEV_CONFIG); \
	echo "# Migration User" >> $(DEV_CONFIG); \
	echo "DB_MIGRATION_USER=migration" >> $(DEV_CONFIG); \
	echo "DB_MIGRATION_PASSWORD=migration" >> $(DEV_CONFIG); \
	echo "" >> $(DEV_CONFIG); \
	echo "# Keycloak Database" >> $(DEV_CONFIG); \
	echo "DB_KEYCLOAK_HOST=postgres" >> $(DEV_CONFIG); \
	echo "DB_KEYCLOAK_PORT=5432" >> $(DEV_CONFIG); \
	echo "DB_KEYCLOAK_NAME=keystone_db" >> $(DEV_CONFIG); \
	echo "DB_KEYCLOAK_SCHEMA=keycloak" >> $(DEV_CONFIG); \
	echo "DB_KEYCLOAK_USER=keycloak" >> $(DEV_CONFIG); \
	echo "DB_KEYCLOAK_PASSWORD=keycloak" >> $(DEV_CONFIG); \
	echo "" >> $(DEV_CONFIG); \
	echo "# Keycloak Admin" >> $(DEV_CONFIG); \
	echo "KEYCLOAK_ADMIN=admin" >> $(DEV_CONFIG); \
	echo "KEYCLOAK_ADMIN_PASSWORD=admin" >> $(DEV_CONFIG); \
	echo "" >> $(DEV_CONFIG); \
	echo "# Keycloak Test User" >> $(DEV_CONFIG); \
	echo "KEYCLOAK_TEST_USER=testuser" >> $(DEV_CONFIG); \
	echo "KEYCLOAK_TEST_PASSWORD=testuser" >> $(DEV_CONFIG); \
	\
	echo ""; \
	echo "[OK] Dev config saved to $(DEV_CONFIG)"

# ============================================================
# SETUP STAGING - Cloud VM, default credentials
# ============================================================
setup-staging:
	@if [ -z "$(CLOUD_PROVIDER)" ] || [ -z "$(AI_PROVIDER)" ]; then \
		echo "╔════════════════════════════════════════╗"; \
		echo "║       Staging Setup (Cloud)            ║"; \
		echo "╚════════════════════════════════════════╝"; \
		echo ""; \
		if [ -z "$(CLOUD_PROVIDER)" ]; then \
			echo "┌─ Cloud Provider ─────────────────────────"; \
			echo "│  1) AWS"; \
			echo "│  2) GCP"; \
			echo "│  3) Azure"; \
			echo "└──────────────────────────────────────────"; \
			read -p "Enter choice [1-3]: " cloud_choice; \
			case $$cloud_choice in \
				1) provider="aws";; \
				2) provider="gcp";; \
				3) provider="azure";; \
				*) echo "[FAIL] Invalid choice"; exit 1;; \
			esac; \
		else \
			provider="$(CLOUD_PROVIDER)"; \
		fi; \
		echo ""; \
		if [ -z "$(AI_PROVIDER)" ]; then \
			echo "┌─ AI Provider ──────────────────────────────"; \
			echo "│  1) OpenAI"; \
			echo "│  2) Gemini (Google)"; \
			echo "│  3) Anthropic"; \
			echo "│  4) Mistral"; \
			echo "│  5) Ollama (local)"; \
			echo "│  6) LM Studio (local)"; \
			echo "└──────────────────────────────────────────"; \
			read -p "Enter choice [1-6]: " ai_choice; \
			case $$ai_choice in \
				1) ai_provider="openai"; ai_key_name="OPENAI_API_KEY";; \
				2) ai_provider="gemini"; ai_key_name="GOOGLE_API_KEY";; \
				3) ai_provider="anthropic"; ai_key_name="ANTHROPIC_API_KEY";; \
				4) ai_provider="mistral"; ai_key_name="MISTRAL_API_KEY";; \
				5) ai_provider="ollama"; ai_key_name="";; \
				6) ai_provider="lmstudio"; ai_key_name="";; \
				*) echo "[FAIL] Invalid choice"; exit 1;; \
			esac; \
			ai_api_key=""; \
			ai_url=""; \
			if [ -n "$$ai_key_name" ]; then \
				echo ""; \
				read -s -p "Enter $$ai_key_name: " ai_api_key; \
				echo ""; \
			else \
				if [ "$$ai_provider" = "ollama" ]; then \
					default_url="http://localhost:11434"; \
				else \
					default_url="http://localhost:1234"; \
				fi; \
				echo ""; \
				read -p "Enter $$ai_provider URL [$$default_url]: " ai_url; \
				ai_url=$${ai_url:-$$default_url}; \
			fi; \
		else \
			ai_provider="$(AI_PROVIDER)"; \
			ai_api_key="$(AI_API_KEY)"; \
			ai_url="$(AI_URL)"; \
			case $$ai_provider in \
				openai) ai_key_name="OPENAI_API_KEY";; \
				gemini) ai_key_name="GOOGLE_API_KEY";; \
				anthropic) ai_key_name="ANTHROPIC_API_KEY";; \
				mistral) ai_key_name="MISTRAL_API_KEY";; \
				ollama|lmstudio) ai_key_name="";; \
				*) echo "[FAIL] Invalid AI_PROVIDER: $$ai_provider"; exit 1;; \
			esac; \
			if [ -z "$$ai_key_name" ] && [ -z "$$ai_url" ]; then \
				if [ "$$ai_provider" = "ollama" ]; then \
					ai_url="http://localhost:11434"; \
				else \
					ai_url="http://localhost:1234"; \
				fi; \
			fi; \
		fi; \
	else \
		provider="$(CLOUD_PROVIDER)"; \
		ai_provider="$(AI_PROVIDER)"; \
		ai_api_key="$(AI_API_KEY)"; \
		ai_url="$(AI_URL)"; \
		case $$ai_provider in \
			openai) ai_key_name="OPENAI_API_KEY";; \
			gemini) ai_key_name="GOOGLE_API_KEY";; \
			anthropic) ai_key_name="ANTHROPIC_API_KEY";; \
			mistral) ai_key_name="MISTRAL_API_KEY";; \
			ollama|lmstudio) ai_key_name="";; \
			*) echo "[FAIL] Invalid AI_PROVIDER: $$ai_provider"; exit 1;; \
		esac; \
		if [ -z "$$ai_key_name" ] && [ -z "$$ai_url" ]; then \
			if [ "$$ai_provider" = "ollama" ]; then \
				ai_url="http://localhost:11434"; \
			else \
				ai_url="http://localhost:1234"; \
			fi; \
		fi; \
	fi; \
	\
	echo "# Auto-generated by make setup-staging" > $(STAGING_CONFIG); \
	echo "" >> $(STAGING_CONFIG); \
	echo "# Cloud & Environment" >> $(STAGING_CONFIG); \
	echo "CLOUD_PROVIDER=$$provider" >> $(STAGING_CONFIG); \
	echo "ENVIRONMENT=staging" >> $(STAGING_CONFIG); \
	echo "" >> $(STAGING_CONFIG); \
	echo "# AI Provider" >> $(STAGING_CONFIG); \
	echo "AI_PROVIDER=$$ai_provider" >> $(STAGING_CONFIG); \
	if [ -n "$$ai_key_name" ] && [ -n "$$ai_api_key" ]; then \
		echo "$$ai_key_name=$$ai_api_key" >> $(STAGING_CONFIG); \
	fi; \
	if [ -n "$$ai_url" ]; then \
		echo "AI_URL=$$ai_url" >> $(STAGING_CONFIG); \
	fi; \
	echo "" >> $(STAGING_CONFIG); \
	echo "# PostgreSQL Superuser" >> $(STAGING_CONFIG); \
	echo "POSTGRES_PASSWORD=postgres" >> $(STAGING_CONFIG); \
	echo "" >> $(STAGING_CONFIG); \
	echo "# Application Database" >> $(STAGING_CONFIG); \
	echo "DB_APP_HOST=postgres" >> $(STAGING_CONFIG); \
	echo "DB_APP_PORT=5432" >> $(STAGING_CONFIG); \
	echo "DB_APP_NAME=keystone_db" >> $(STAGING_CONFIG); \
	echo "DB_APP_SCHEMA=app" >> $(STAGING_CONFIG); \
	echo "DB_APP_USER=appuser" >> $(STAGING_CONFIG); \
	echo "DB_APP_PASSWORD=appuser" >> $(STAGING_CONFIG); \
	echo "" >> $(STAGING_CONFIG); \
	echo "# Migration User" >> $(STAGING_CONFIG); \
	echo "DB_MIGRATION_USER=migration" >> $(STAGING_CONFIG); \
	echo "DB_MIGRATION_PASSWORD=migration" >> $(STAGING_CONFIG); \
	echo "" >> $(STAGING_CONFIG); \
	echo "# Keycloak Database" >> $(STAGING_CONFIG); \
	echo "DB_KEYCLOAK_HOST=postgres" >> $(STAGING_CONFIG); \
	echo "DB_KEYCLOAK_PORT=5432" >> $(STAGING_CONFIG); \
	echo "DB_KEYCLOAK_NAME=keystone_db" >> $(STAGING_CONFIG); \
	echo "DB_KEYCLOAK_SCHEMA=keycloak" >> $(STAGING_CONFIG); \
	echo "DB_KEYCLOAK_USER=keycloak" >> $(STAGING_CONFIG); \
	echo "DB_KEYCLOAK_PASSWORD=keycloak" >> $(STAGING_CONFIG); \
	echo "" >> $(STAGING_CONFIG); \
	echo "# Keycloak Admin" >> $(STAGING_CONFIG); \
	echo "KEYCLOAK_ADMIN=admin" >> $(STAGING_CONFIG); \
	echo "KEYCLOAK_ADMIN_PASSWORD=admin" >> $(STAGING_CONFIG); \
	echo "" >> $(STAGING_CONFIG); \
	echo "# Keycloak Test User" >> $(STAGING_CONFIG); \
	echo "KEYCLOAK_TEST_USER=testuser" >> $(STAGING_CONFIG); \
	echo "KEYCLOAK_TEST_PASSWORD=testuser" >> $(STAGING_CONFIG); \
	\
	echo ""; \
	echo "[OK] Staging config saved to $(STAGING_CONFIG)"

# ============================================================
# SETUP DEPLOY (PROD) - Cloud VM, manual credentials
# ============================================================
setup-deploy:
	@if [ -z "$(CLOUD_PROVIDER)" ]; then \
		echo "╔════════════════════════════════════════╗"; \
		echo "║      Production Setup (Cloud)          ║"; \
		echo "╚════════════════════════════════════════╝"; \
		echo ""; \
		echo "┌─ Cloud Provider ─────────────────────────"; \
		echo "│  1) AWS"; \
		echo "│  2) GCP"; \
		echo "│  3) Azure"; \
		echo "│  4) Scaleway"; \
		echo "└──────────────────────────────────────────"; \
		read -p "Enter choice [1-4]: " cloud_choice; \
		case $$cloud_choice in \
			1) provider="aws";; \
			2) provider="gcp";; \
			3) provider="azure";; \
			4) provider="scaleway";; \
			*) echo "[FAIL] Invalid choice"; exit 1;; \
		esac; \
	else \
		provider="$(CLOUD_PROVIDER)"; \
		case $$provider in \
			aws|gcp|azure|scaleway) ;; \
			*) echo "[FAIL] Invalid CLOUD_PROVIDER: $$provider"; exit 1;; \
		esac; \
	fi; \
	\
	if [ -z "$(INFRA_TYPE)" ]; then \
		echo ""; \
		echo "┌─ Infrastructure Type ───────────────────"; \
		echo "│  1) VM + Attached Storage (PostgreSQL on VM)"; \
		echo "│  2) VM + Managed Database (Cloud SQL/RDS)"; \
		echo "│  3) Kubernetes (K8S)"; \
		echo "└──────────────────────────────────────────"; \
		read -p "Enter choice [1-3]: " infra_choice; \
		case $$infra_choice in \
			1) infra_type="vm-attached-storage";; \
			2) infra_type="vm-managed-postgres";; \
			3) infra_type="k8s-managed-postgres";; \
			*) echo "[FAIL] Invalid choice"; exit 1;; \
		esac; \
	else \
		infra_type="$(INFRA_TYPE)"; \
		case $$infra_type in \
			vm-attached-storage|vm-managed-postgres|k8s-managed-postgres) ;; \
			*) echo "[FAIL] Invalid INFRA_TYPE: $$infra_type"; exit 1;; \
		esac; \
	fi; \
	\
	echo "┌─ Infrastructure Settings ──────────────────"; \
	echo "└──────────────────────────────────────────"; \
	if [ -z "$(CLOUD_REGION)" ]; then \
		case $$provider in \
			aws) default_region="eu-west-3";; \
			gcp) default_region="europe-west1";; \
			azure) default_region="westeurope";; \
			scaleway) default_region="fr-par";; \
		esac; \
		read -p "Region [$$default_region]: " cloud_region; \
		cloud_region=$${cloud_region:-$$default_region}; \
	else \
		cloud_region="$(CLOUD_REGION)"; \
	fi; \
	if [ -z "$(DOMAIN_NAME)" ]; then \
		read -p "Domain name (e.g., app.example.com): " domain_name; \
	else \
		domain_name="$(DOMAIN_NAME)"; \
	fi; \
	if [ -z "$(ELASTIC_IP)" ] && [ "$$provider" = "aws" ]; then \
		read -p "Existing Elastic IP (leave empty to create new): " elastic_ip; \
	else \
		elastic_ip="$(ELASTIC_IP)"; \
	fi; \
	if [ -z "$(ELASTIC_IP_ALLOC_ID)" ] && [ -n "$$elastic_ip" ] && [ "$$provider" = "aws" ]; then \
		read -p "Elastic IP Allocation ID (eipalloc-xxx): " elastic_ip_alloc_id; \
	else \
		elastic_ip_alloc_id="$(ELASTIC_IP_ALLOC_ID)"; \
	fi; \
	\
	if [ "$$provider" = "azure" ]; then \
		if [ -z "$(AZURE_SUBSCRIPTION_ID)" ]; then \
			azure_sub_id=$$(az account show --query id -o tsv 2>/dev/null); \
			if [ -z "$$azure_sub_id" ]; then \
				read -p "Azure Subscription ID: " azure_sub_id; \
			else \
				echo "Using Azure Subscription: $$azure_sub_id"; \
			fi; \
		else \
			azure_sub_id="$(AZURE_SUBSCRIPTION_ID)"; \
		fi; \
		if [ -z "$(AZURE_PERMANENT_RG)" ]; then \
			read -p "Permanent Resource Group [keystone-permanent-rg]: " azure_permanent_rg; \
			azure_permanent_rg=$${azure_permanent_rg:-keystone-permanent-rg}; \
		else \
			azure_permanent_rg="$(AZURE_PERMANENT_RG)"; \
		fi; \
		if [ -z "$(AZURE_PUBLIC_IP_NAME)" ]; then \
			read -p "Public IP name [keystone-public-ip]: " azure_public_ip_name; \
			azure_public_ip_name=$${azure_public_ip_name:-keystone-public-ip}; \
		else \
			azure_public_ip_name="$(AZURE_PUBLIC_IP_NAME)"; \
		fi; \
		if [ -z "$(AZURE_STORAGE_ACCOUNT)" ]; then \
			read -p "Storage Account name: " azure_storage_account; \
		else \
			azure_storage_account="$(AZURE_STORAGE_ACCOUNT)"; \
		fi; \
		if [ -z "$(AZURE_STORAGE_CONTAINER)" ]; then \
			read -p "Storage Container [caddy]: " azure_storage_container; \
			azure_storage_container=$${azure_storage_container:-caddy}; \
		else \
			azure_storage_container="$(AZURE_STORAGE_CONTAINER)"; \
		fi; \
		if [ -z "$(SSH_ALLOWED_CIDRS)" ]; then \
			current_ip=$$(curl -4 -s ifconfig.me 2>/dev/null); \
			if [ -n "$$current_ip" ]; then \
				default_ssh_cidrs="$$current_ip/32"; \
			else \
				default_ssh_cidrs=""; \
			fi; \
			read -p "SSH allowed CIDRs [$$default_ssh_cidrs]: " ssh_allowed_cidrs; \
			ssh_allowed_cidrs=$${ssh_allowed_cidrs:-$$default_ssh_cidrs}; \
		else \
			ssh_allowed_cidrs="$(SSH_ALLOWED_CIDRS)"; \
		fi; \
	fi; \
	\
	if [ -z "$(AI_PROVIDER)" ]; then \
		echo ""; \
		echo "┌─ AI Provider ──────────────────────────────"; \
		echo "│  1) OpenAI"; \
		echo "│  2) Anthropic"; \
		echo "│  3) Google Gemini"; \
		echo "│  4) Mistral"; \
		echo "│  5) Ollama (self-hosted)"; \
		echo "│  6) LM Studio (self-hosted)"; \
		echo "└──────────────────────────────────────────"; \
		read -p "Enter choice [1-6]: " ai_choice; \
		case $$ai_choice in \
			1) ai_provider="openai"; ai_key_name="OPENAI_API_KEY";; \
			2) ai_provider="anthropic"; ai_key_name="ANTHROPIC_API_KEY";; \
			3) ai_provider="gemini"; ai_key_name="GOOGLE_API_KEY";; \
			4) ai_provider="mistral"; ai_key_name="MISTRAL_API_KEY";; \
			5) ai_provider="ollama"; ai_key_name="";; \
			6) ai_provider="lmstudio"; ai_key_name="";; \
			*) echo "[FAIL] Invalid choice"; exit 1;; \
		esac; \
		ai_api_key=""; \
		ai_url=""; \
		if [ -n "$$ai_key_name" ]; then \
			echo ""; \
			read -s -p "Enter $$ai_key_name: " ai_api_key; \
			echo ""; \
		else \
			echo ""; \
			read -p "Enter $$ai_provider URL: " ai_url; \
		fi; \
	else \
		ai_provider="$(AI_PROVIDER)"; \
		ai_api_key="$(AI_API_KEY)"; \
		ai_url="$(AI_URL)"; \
		case $$ai_provider in \
			openai) ai_key_name="OPENAI_API_KEY";; \
			anthropic) ai_key_name="ANTHROPIC_API_KEY";; \
			gemini) ai_key_name="GOOGLE_API_KEY";; \
			mistral) ai_key_name="MISTRAL_API_KEY";; \
			ollama|lmstudio) ai_key_name="";; \
			*) echo "[FAIL] Invalid AI_PROVIDER: $$ai_provider"; exit 1;; \
		esac; \
	fi; \
	\
	echo ""; \
	echo "┌─ Database Credentials ─────────────────────"; \
	echo "│  Configure passwords for database users"; \
	echo "└──────────────────────────────────────────"; \
	echo ""; \
	if [ -z "$(POSTGRES_PASSWORD)" ]; then \
		read -s -p "PostgreSQL superuser password: " pg_password; echo ""; \
	else \
		pg_password="$(POSTGRES_PASSWORD)"; \
	fi; \
	if [ -z "$(DB_MIGRATION_PASSWORD)" ]; then \
		read -s -p "Migration user password: " mig_password; echo ""; \
	else \
		mig_password="$(DB_MIGRATION_PASSWORD)"; \
	fi; \
	if [ -z "$(DB_APP_PASSWORD)" ]; then \
		read -s -p "App user password: " app_password; echo ""; \
	else \
		app_password="$(DB_APP_PASSWORD)"; \
	fi; \
	if [ -z "$(DB_KEYCLOAK_PASSWORD)" ]; then \
		read -s -p "Keycloak DB user password: " kc_db_password; echo ""; \
	else \
		kc_db_password="$(DB_KEYCLOAK_PASSWORD)"; \
	fi; \
	\
	validate_pw() { \
		case "$$1" in \
			*@*|*:*|*/*|*\#*) echo "[FAIL] Password cannot contain @, :, /, or # characters"; exit 1;; \
		esac; \
	}; \
	validate_pw "$$pg_password"; \
	validate_pw "$$mig_password"; \
	validate_pw "$$app_password"; \
	validate_pw "$$kc_db_password"; \
	\
	db_app_host="$${DB_APP_HOST:-postgres}"; \
	db_app_port="$${DB_APP_PORT:-5432}"; \
	db_app_name="$${DB_APP_NAME:-keystone_db}"; \
	db_app_schema="$${DB_APP_SCHEMA:-app}"; \
	app_user="$${DB_APP_USER:-appuser}"; \
	mig_user="$${DB_MIGRATION_USER:-migration}"; \
	db_kc_host="$${DB_KEYCLOAK_HOST:-postgres}"; \
	db_kc_port="$${DB_KEYCLOAK_PORT:-5432}"; \
	db_kc_name="$${DB_KEYCLOAK_NAME:-keystone_db}"; \
	db_kc_schema="$${DB_KEYCLOAK_SCHEMA:-keycloak}"; \
	kc_db_user="$${DB_KEYCLOAK_USER:-keycloak}"; \
	\
	echo ""; \
	echo "┌─ Application Credentials ──────────────────"; \
	echo "│  Configure admin accounts"; \
	echo "└──────────────────────────────────────────"; \
	echo ""; \
	if [ -z "$(KEYSTONE_ADMIN)" ]; then \
		read -p "Keystone admin username [adminuser]: " ks_admin; \
		ks_admin=$${ks_admin:-adminuser}; \
	else \
		ks_admin="$(KEYSTONE_ADMIN)"; \
	fi; \
	if [ -z "$(KEYSTONE_ADMIN_PASSWORD)" ]; then \
		read -s -p "Keystone admin password: " ks_admin_password; echo ""; \
	else \
		ks_admin_password="$(KEYSTONE_ADMIN_PASSWORD)"; \
	fi; \
	if [ -z "$(KEYCLOAK_ADMIN)" ]; then \
		read -p "Keycloak admin username [admin]: " kc_admin; \
		kc_admin=$${kc_admin:-admin}; \
	else \
		kc_admin="$(KEYCLOAK_ADMIN)"; \
	fi; \
	if [ -z "$(KEYCLOAK_ADMIN_PASSWORD)" ]; then \
		read -s -p "Keycloak admin password: " kc_admin_password; echo ""; \
	else \
		kc_admin_password="$(KEYCLOAK_ADMIN_PASSWORD)"; \
	fi; \
	\
	if [ "$$provider" = "aws" ]; then \
		if [ -z "$(CADDY_BUCKET_NAME)" ]; then \
			read -p "Caddy S3 bucket name: " caddy_bucket; \
		else \
			caddy_bucket="$(CADDY_BUCKET_NAME)"; \
		fi; \
	fi; \
	\
	echo ""; \
	echo "# Auto-generated by make setup-deploy" > $(DEPLOY_CONFIG); \
	echo "" >> $(DEPLOY_CONFIG); \
	echo "# Infrastructure" >> $(DEPLOY_CONFIG); \
	echo "CLOUD_PROVIDER=$$provider" >> $(DEPLOY_CONFIG); \
	echo "CLOUD_REGION=$$cloud_region" >> $(DEPLOY_CONFIG); \
	echo "INFRA_TYPE=$$infra_type" >> $(DEPLOY_CONFIG); \
	echo "ENVIRONMENT=prod" >> $(DEPLOY_CONFIG); \
	echo "" >> $(DEPLOY_CONFIG); \
	echo "# Domain & Network" >> $(DEPLOY_CONFIG); \
	echo "DOMAIN_NAME=$$domain_name" >> $(DEPLOY_CONFIG); \
	if [ -n "$$elastic_ip" ]; then \
		echo "ELASTIC_IP=$$elastic_ip" >> $(DEPLOY_CONFIG); \
	fi; \
	if [ -n "$$elastic_ip_alloc_id" ]; then \
		echo "ELASTIC_IP_ALLOC_ID=$$elastic_ip_alloc_id" >> $(DEPLOY_CONFIG); \
	fi; \
	if [ "$$provider" = "azure" ]; then \
		echo "" >> $(DEPLOY_CONFIG); \
		echo "# Azure Specific" >> $(DEPLOY_CONFIG); \
		echo "AZURE_SUBSCRIPTION_ID=$$azure_sub_id" >> $(DEPLOY_CONFIG); \
		echo "AZURE_PERMANENT_RG=$$azure_permanent_rg" >> $(DEPLOY_CONFIG); \
		echo "AZURE_PUBLIC_IP_NAME=$$azure_public_ip_name" >> $(DEPLOY_CONFIG); \
		echo "AZURE_STORAGE_ACCOUNT=$$azure_storage_account" >> $(DEPLOY_CONFIG); \
		echo "AZURE_STORAGE_CONTAINER=$$azure_storage_container" >> $(DEPLOY_CONFIG); \
		echo "SSH_ALLOWED_CIDRS=$$ssh_allowed_cidrs" >> $(DEPLOY_CONFIG); \
	fi; \
	echo "" >> $(DEPLOY_CONFIG); \
	echo "# AI Provider" >> $(DEPLOY_CONFIG); \
	echo "AI_PROVIDER=$$ai_provider" >> $(DEPLOY_CONFIG); \
	if [ -n "$$ai_key_name" ] && [ -n "$$ai_api_key" ]; then \
		echo "$$ai_key_name=$$ai_api_key" >> $(DEPLOY_CONFIG); \
	fi; \
	if [ -n "$$ai_url" ]; then \
		echo "AI_URL=$$ai_url" >> $(DEPLOY_CONFIG); \
	fi; \
	echo "" >> $(DEPLOY_CONFIG); \
	echo "# PostgreSQL Superuser" >> $(DEPLOY_CONFIG); \
	echo "POSTGRES_PASSWORD=$$pg_password" >> $(DEPLOY_CONFIG); \
	echo "" >> $(DEPLOY_CONFIG); \
	echo "# Application Database" >> $(DEPLOY_CONFIG); \
	echo "DB_APP_HOST=$$db_app_host" >> $(DEPLOY_CONFIG); \
	echo "DB_APP_PORT=$$db_app_port" >> $(DEPLOY_CONFIG); \
	echo "DB_APP_NAME=$$db_app_name" >> $(DEPLOY_CONFIG); \
	echo "DB_APP_SCHEMA=$$db_app_schema" >> $(DEPLOY_CONFIG); \
	echo "DB_APP_USER=$$app_user" >> $(DEPLOY_CONFIG); \
	echo "DB_APP_PASSWORD=$$app_password" >> $(DEPLOY_CONFIG); \
	echo "" >> $(DEPLOY_CONFIG); \
	echo "# Migration User" >> $(DEPLOY_CONFIG); \
	echo "DB_MIGRATION_USER=$$mig_user" >> $(DEPLOY_CONFIG); \
	echo "DB_MIGRATION_PASSWORD=$$mig_password" >> $(DEPLOY_CONFIG); \
	echo "" >> $(DEPLOY_CONFIG); \
	echo "# Keycloak Database" >> $(DEPLOY_CONFIG); \
	echo "DB_KEYCLOAK_HOST=$$db_kc_host" >> $(DEPLOY_CONFIG); \
	echo "DB_KEYCLOAK_PORT=$$db_kc_port" >> $(DEPLOY_CONFIG); \
	echo "DB_KEYCLOAK_NAME=$$db_kc_name" >> $(DEPLOY_CONFIG); \
	echo "DB_KEYCLOAK_SCHEMA=$$db_kc_schema" >> $(DEPLOY_CONFIG); \
	echo "DB_KEYCLOAK_USER=$$kc_db_user" >> $(DEPLOY_CONFIG); \
	echo "DB_KEYCLOAK_PASSWORD=$$kc_db_password" >> $(DEPLOY_CONFIG); \
	echo "" >> $(DEPLOY_CONFIG); \
	echo "# Keystone Admin" >> $(DEPLOY_CONFIG); \
	echo "KEYSTONE_ADMIN=$$ks_admin" >> $(DEPLOY_CONFIG); \
	echo "KEYSTONE_ADMIN_PASSWORD=$$ks_admin_password" >> $(DEPLOY_CONFIG); \
	echo "" >> $(DEPLOY_CONFIG); \
	echo "# Keycloak Admin" >> $(DEPLOY_CONFIG); \
	echo "KEYCLOAK_ADMIN=$$kc_admin" >> $(DEPLOY_CONFIG); \
	echo "KEYCLOAK_ADMIN_PASSWORD=$$kc_admin_password" >> $(DEPLOY_CONFIG); \
	echo "" >> $(DEPLOY_CONFIG); \
	if [ "$$provider" = "aws" ]; then \
		echo "# Caddy S3 bucket" >> $(DEPLOY_CONFIG); \
		echo "CADDY_BUCKET_NAME=$$caddy_bucket" >> $(DEPLOY_CONFIG); \
	fi; \
	\
	echo ""; \
	echo "[OK] Production config saved to $(DEPLOY_CONFIG)"; \
	echo ""; \
	echo "Configuration summary:"; \
	echo "  Cloud Provider: $$provider ($$cloud_region)"; \
	echo "  Infrastructure: $$infra_type"; \
	echo "  Domain: $$domain_name"; \
	if [ -n "$$elastic_ip" ]; then \
		echo "  Elastic IP: $$elastic_ip"; \
	fi; \
	if [ "$$provider" = "azure" ]; then \
		echo "  Subscription: $$azure_sub_id"; \
		echo "  Permanent RG: $$azure_permanent_rg"; \
		echo "  Storage Account: $$azure_storage_account"; \
	fi; \
	echo "  AI Provider: $$ai_provider"; \
	echo ""; \
	echo "Next steps:"; \
	echo "  1. Review $(DEPLOY_CONFIG)"; \
	echo "  2. Run 'make infra-init' to initialize OpenTofu"; \
	echo "  3. Run 'make infra-plan' to preview infrastructure"; \
	echo "  4. Run 'make infra-apply' to deploy"

test-setup:
	@./scripts/test-setup.sh

# ============================================================
# DOCKER COMMANDS
# ============================================================
.PHONY: dev-up dev-down dev-logs dev-ps dev-clean reindex-documents

dev-up:
	@if [ ! -f $(DEV_CONFIG) ]; then \
		echo "[FAIL] $(DEV_CONFIG) not found. Run 'make setup-dev' first."; \
		exit 1; \
	fi
	@if [ ! -f frontend/.env.local ]; then $(MAKE) frontend-env; fi
	@echo "[INFO] Starting development environment..."
	@set -a && . ./$(DEV_CONFIG) && set +a && docker compose up -d
	@echo "[OK] Development environment started"
	@sleep 5
	@$(MAKE) db-migrate
	@echo ""
	@echo "Services:"
	@echo "  - PostgreSQL: localhost:5432"
	@echo "  - Keycloak:   http://localhost:8080"
	@echo "  - Backend:    http://localhost:8000"
	@echo ""
	@echo "To start the frontend, run: make frontend"

dev-down:
	@echo "[INFO] Stopping development environment..."
	@docker compose down
	@echo "[OK] Development environment stopped"

dev-logs:
	@docker compose logs -f

dev-ps:
	@docker compose ps

dev-clean:
	@echo "[WARN] This will delete all data (database, volumes)!"
	@read -p "Are you sure? [y/N]: " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		docker compose down -v; \
		echo "[OK] Development environment cleaned"; \
	else \
		echo "[INFO] Cancelled"; \
	fi

reindex-documents:
	@echo "[INFO] Reindexing documents with current embedding configuration..."
	@curl -s -X POST http://localhost:8000/api/admin/reindex | python3 -m json.tool || echo "[FAIL] Backend not running or reindex failed"

# ============================================================
# FRONTEND ENV GENERATION
# ============================================================
.PHONY: frontend-env

frontend-env:
	@if [ -f frontend/.env.local ]; then echo "[OK] frontend/.env.local already exists, skipping"; exit 0; fi
	@echo "# Auto-generated by make frontend-env" > frontend/.env.local
	@echo "" >> frontend/.env.local
	@echo "# Backend" >> frontend/.env.local
	@echo "BACKEND_URL=http://localhost:8000" >> frontend/.env.local
	@echo "" >> frontend/.env.local
	@echo "# NextAuth" >> frontend/.env.local
	@echo "AUTH_SECRET=$$(openssl rand -base64 32)" >> frontend/.env.local
	@echo "" >> frontend/.env.local
	@echo "# Keycloak" >> frontend/.env.local
	@echo "KEYCLOAK_CLIENT_ID=keystone-app" >> frontend/.env.local
	@echo "KEYCLOAK_CLIENT_SECRET=keystone-secret" >> frontend/.env.local
	@echo "KEYCLOAK_ISSUER=http://localhost:8080/realms/keystone" >> frontend/.env.local
	@echo "[OK] Frontend env saved to frontend/.env.local"

# ============================================================
# FRONTEND COMMANDS
# ============================================================
.PHONY: frontend frontend-install

frontend-install:
	@echo "[INFO] Installing frontend dependencies..."
	@cd frontend && pnpm install
	@echo "[OK] Frontend dependencies installed"

frontend:
	@if [ ! -d frontend/node_modules ]; then $(MAKE) frontend-install; fi
	@echo "[INFO] Starting frontend..."
	@cd frontend && pnpm dev

# ============================================================
# DATABASE MIGRATIONS
# ============================================================
.PHONY: db-migrate

db-migrate:
	@echo "[INFO] Running database migrations..."
	@for migration in docker/postgres/migrations/*.sql; do \
		echo "  - Running $$migration..."; \
		docker exec -i keystone-postgres psql -U postgres -d keystone_db < "$$migration" 2>/dev/null || true; \
	done
	@echo "[OK] Migrations complete"

# ============================================================
# INFRASTRUCTURE - OpenTofu commands
# ============================================================

INFRA_DIR = infra

.PHONY: infra-init infra-plan infra-apply infra-destroy infra-output

infra-init:
	@if [ ! -f $(DEPLOY_CONFIG) ]; then \
		echo "[ERROR] Run 'make setup-deploy' first"; \
		exit 1; \
	fi
	@. $(DEPLOY_CONFIG) && \
	INFRA_PATH="$(INFRA_DIR)/$$CLOUD_PROVIDER/$$INFRA_TYPE" && \
	if [ ! -d "$$INFRA_PATH" ]; then \
		echo "[ERROR] Infrastructure not found: $$INFRA_PATH"; \
		exit 1; \
	fi && \
	echo "[INFO] Generating terraform.tfvars..." && \
	$$INFRA_PATH/generate-tfvars.sh && \
	echo "[INFO] Initializing OpenTofu in $$INFRA_PATH..." && \
	cd $$INFRA_PATH && tofu init

infra-plan:
	@if [ ! -f $(DEPLOY_CONFIG) ]; then \
		echo "[ERROR] Run 'make setup-deploy' first"; \
		exit 1; \
	fi
	@. $(DEPLOY_CONFIG) && \
	INFRA_PATH="$(INFRA_DIR)/$$CLOUD_PROVIDER/$$INFRA_TYPE" && \
	echo "[INFO] Planning infrastructure in $$INFRA_PATH..." && \
	cd $$INFRA_PATH && tofu plan

infra-apply:
	@if [ ! -f $(DEPLOY_CONFIG) ]; then \
		echo "[ERROR] Run 'make setup-deploy' first"; \
		exit 1; \
	fi
	@. $(DEPLOY_CONFIG) && \
	INFRA_PATH="$(INFRA_DIR)/$$CLOUD_PROVIDER/$$INFRA_TYPE" && \
	echo "[INFO] Applying infrastructure in $$INFRA_PATH..." && \
	cd $$INFRA_PATH && tofu apply

infra-destroy:
	@if [ ! -f $(DEPLOY_CONFIG) ]; then \
		echo "[ERROR] Run 'make setup-deploy' first"; \
		exit 1; \
	fi
	@. $(DEPLOY_CONFIG) && \
	INFRA_PATH="$(INFRA_DIR)/$$CLOUD_PROVIDER/$$INFRA_TYPE" && \
	echo "[WARNING] Destroying infrastructure in $$INFRA_PATH..." && \
	cd $$INFRA_PATH && tofu destroy

infra-output:
	@if [ ! -f $(DEPLOY_CONFIG) ]; then \
		echo "[ERROR] Run 'make setup-deploy' first"; \
		exit 1; \
	fi
	@. $(DEPLOY_CONFIG) && \
	INFRA_PATH="$(INFRA_DIR)/$$CLOUD_PROVIDER/$$INFRA_TYPE" && \
	cd $$INFRA_PATH && tofu output
