.PHONY: help install up down restart logs ps status clean encrypt decrypt edit check-secrets update pull set

# Variables
COMPOSE_FILE := compose.yaml
SCRIPTS_DIR := scripts
ENV_FILES := .env .env.admin .env.client

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

# Show help for available commands
help:
	@echo "$(GREEN)Available commands:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

# ============================================
# Docker Compose commands
# ============================================

up: ## Start all services
	@echo "$(GREEN)Starting all services...$(NC)"
	docker compose -f $(COMPOSE_FILE) up -d --remove-orphans
	@echo "$(GREEN)✓ Services started$(NC)"

down: ## Stop all services
	@echo "$(YELLOW)Stopping all services...$(NC)"
	docker compose -f $(COMPOSE_FILE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: ## Restart all services
	@echo "$(YELLOW)Restarting all services...$(NC)"
	docker compose -f $(COMPOSE_FILE) restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

logs: ## Show logs for all services
	docker compose -f $(COMPOSE_FILE) logs -f

logs-traefik: ## Show Traefik logs
	docker compose -f $(COMPOSE_FILE) logs -f traefik

logs-client: ## Show client application logs
	docker compose -f $(COMPOSE_FILE) logs -f lf-client

logs-admin: ## Show admin panel logs
	docker compose -f $(COMPOSE_FILE) logs -f lf-admin

ps: ## Show container status
	docker compose -f $(COMPOSE_FILE) ps

status: ps ## Show container status (alias for ps)

pull: ## Update Docker images
	@echo "$(GREEN)Updating images...$(NC)"
	docker compose -f $(COMPOSE_FILE) pull
	@echo "$(GREEN)✓ Images updated$(NC)"

update: pull restart ## Update images and restart services
	@echo "$(GREEN)✓ Update completed$(NC)"

# ============================================
# .env file management
# ============================================

encrypt: ## Encrypt all .env files (usage: make encrypt [.env])
	@FILE="$(word 2,$(MAKECMDGOALS))"; \
	if [ -z "$$FILE" ]; then \
		echo "$(GREEN)Encrypting all .env files...$(NC)"; \
		$(SCRIPTS_DIR)/encrypt-env.sh; \
	else \
		echo "$(GREEN)Encrypting $$FILE...$(NC)"; \
		$(SCRIPTS_DIR)/encrypt-env.sh $$FILE; \
	fi; \
	echo "$(GREEN)✓ Encryption completed$(NC)"

decrypt: ## Decrypt all .env files (usage: make decrypt [.env])
	@FILE="$(word 2,$(MAKECMDGOALS))"; \
	if [ -z "$$FILE" ]; then \
		echo "$(YELLOW)Decrypting all .env files...$(NC)"; \
		$(SCRIPTS_DIR)/decrypt-env.sh; \
	else \
		echo "$(YELLOW)Decrypting $$FILE...$(NC)"; \
		$(SCRIPTS_DIR)/decrypt-env.sh $$FILE; \
	fi; \
	echo "$(GREEN)✓ Decryption completed$(NC)"

edit: ## Edit .env file (usage: make edit .env)
	@FILE="$(word 2,$(MAKECMDGOALS))"; \
	if [ -z "$$FILE" ]; then \
		echo "$(RED)Error: specify file, e.g. make edit .env$(NC)"; \
		exit 1; \
	fi; \
	$(SCRIPTS_DIR)/edit-env.sh $$FILE

set: ## Set value in .env file (usage: make set .env KEY=value)
	@FILE="$(word 2,$(MAKECMDGOALS))"; \
	KEY="$(word 3,$(MAKECMDGOALS))"; \
	if [ -z "$$FILE" ] || [ -z "$$KEY" ]; then \
		echo "$(RED)Error: specify file and key=value, e.g. make set .env DATABASE_URL=postgres://...$(NC)"; \
		exit 1; \
	fi; \
	$(SCRIPTS_DIR)/edit-env.sh $$FILE $$KEY

check-secrets: ## Check that all secrets are encrypted
	@echo "$(GREEN)Checking secret encryption...$(NC)"
	@$(SCRIPTS_DIR)/check-env-secrets.sh
	@echo "$(GREEN)✓ All secrets are encrypted$(NC)"

# ============================================
# Utilities
# ============================================

clean: ## Stop and remove containers, networks, volumes
	@echo "$(YELLOW)Cleaning Docker resources...$(NC)"
	@read -p "Are you sure? This will delete all containers and volumes [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	docker compose -f $(COMPOSE_FILE) down -v --remove-orphans
	@echo "$(GREEN)✓ Cleanup completed$(NC)"

validate: check-secrets ## Validate configuration before deployment
	@echo "$(GREEN)Validating Docker Compose configuration...$(NC)"
	@docker compose -f $(COMPOSE_FILE) config > /dev/null
	@echo "$(GREEN)✓ Configuration is valid$(NC)"

install: ## Check if all dependencies are installed
	@echo "$(GREEN)Checking dependencies...$(NC)"
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)Error: Docker is not installed$(NC)"; exit 1; }
	@docker compose version >/dev/null 2>&1 || { echo "$(RED)Error: Docker Compose is not installed$(NC)"; exit 1; }
	@command -v openssl >/dev/null 2>&1 || { echo "$(RED)Error: OpenSSL is not installed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ All dependencies are installed$(NC)"

# ============================================
# Complex commands
# ============================================

deploy: validate up ## Deploy project (validate + start)
	@echo "$(GREEN)✓ Deployment completed$(NC)"

rebuild: down up ## Rebuild and start services

# Prevent Make from trying to build files with these names
%:
	@:

# Default command
.DEFAULT_GOAL := help
