.PHONY: help install up down restart logs ps status clean encrypt decrypt check-secrets pull

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

logs-caddy: ## Show Caddy logs
	docker compose -f $(COMPOSE_FILE) logs -f caddy

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

install: ## Check if all dependencies are installed
	@echo "$(GREEN)Checking dependencies...$(NC)"
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)Error: Docker is not installed$(NC)"; exit 1; }
	@docker compose version >/dev/null 2>&1 || { echo "$(RED)Error: Docker Compose is not installed$(NC)"; exit 1; }
	@command -v openssl >/dev/null 2>&1 || { echo "$(RED)Error: OpenSSL is not installed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ All dependencies are installed$(NC)"

# ============================================
# Complex commands
# ============================================

deploy: up ## Deploy project (start services)
	@echo "$(GREEN)✓ Deployment completed$(NC)"

deploy-applications: pull-applications ## Deploy applications with specific tags
	@echo "$(GREEN)Deploying applications...$(NC)"
	@SERVICES="$$([ -z "$(SERVICES)" ] || [ "$(SERVICES)" = "all" ] && echo "admin client lf-placeholder" || echo "$(SERVICES)" | sed 's/,/ /g' | sed 's/placeholder/lf-placeholder/g')"; \
	ADMIN_TAG="$${ADMIN_TAG:-latest}" CLIENT_TAG="$${CLIENT_TAG:-latest}" PLACEHOLDER_TAG="$${PLACEHOLDER_TAG:-latest}" \
		docker compose -f $(COMPOSE_FILE) stop $$SERVICES 2>/dev/null || true; \
	ADMIN_TAG="$${ADMIN_TAG:-latest}" CLIENT_TAG="$${CLIENT_TAG:-latest}" PLACEHOLDER_TAG="$${PLACEHOLDER_TAG:-latest}" \
		docker compose -f $(COMPOSE_FILE) rm -f $$SERVICES 2>/dev/null || true; \
	ADMIN_TAG="$${ADMIN_TAG:-latest}" CLIENT_TAG="$${CLIENT_TAG:-latest}" PLACEHOLDER_TAG="$${PLACEHOLDER_TAG:-latest}" \
		docker compose -f $(COMPOSE_FILE) up -d $$SERVICES
	@echo "$(GREEN)✓ Applications deployed$(NC)"

deploy-infrastructure: ## Deploy infrastructure services only
	@echo "$(GREEN)Deploying infrastructure...$(NC)"
	@docker compose -f $(COMPOSE_FILE) pull caddy uptime-kuma lf-placeholder || true
	@docker compose -f $(COMPOSE_FILE) up -d caddy uptime-kuma lf-placeholder
	@echo "$(GREEN)✓ Infrastructure deployed$(NC)"

deploy-all: deploy-infrastructure ## Deploy everything (infrastructure + applications)
	@$(MAKE) deploy-applications ADMIN_TAG="$${ADMIN_TAG:-latest}" CLIENT_TAG="$${CLIENT_TAG:-latest}" PLACEHOLDER_TAG="$${PLACEHOLDER_TAG:-latest}"

pull-applications: ## Pull application images with specific tags
	@echo "$(GREEN)Pulling application images...$(NC)"
	@ADMIN_TAG="$${ADMIN_TAG:-latest}"; \
	CLIENT_TAG="$${CLIENT_TAG:-latest}"; \
	PLACEHOLDER_TAG="$${PLACEHOLDER_TAG:-latest}"; \
	echo "Pulling admin:$$ADMIN_TAG"; \
	docker pull ghcr.io/liatoshynsky-foundation/lf-admin:$$ADMIN_TAG 2>/dev/null || { \
		echo "Tag $$ADMIN_TAG not found, pulling latest"; \
		docker pull ghcr.io/liatoshynsky-foundation/lf-admin:latest; \
		docker tag ghcr.io/liatoshynsky-foundation/lf-admin:latest ghcr.io/liatoshynsky-foundation/lf-admin:$$ADMIN_TAG; \
	}; \
	echo "Pulling client:$$CLIENT_TAG"; \
	docker pull ghcr.io/liatoshynsky-foundation/lf-client:$$CLIENT_TAG 2>/dev/null || { \
		echo "Tag $$CLIENT_TAG not found, pulling latest"; \
		docker pull ghcr.io/liatoshynsky-foundation/lf-client:latest; \
		docker tag ghcr.io/liatoshynsky-foundation/lf-client:latest ghcr.io/liatoshynsky-foundation/lf-client:$$CLIENT_TAG; \
	}; \
	echo "Pulling placeholder:$$PLACEHOLDER_TAG"; \
	docker pull ghcr.io/liatoshynsky-foundation/lf-placeholder:$$PLACEHOLDER_TAG 2>/dev/null || { \
		echo "Tag $$PLACEHOLDER_TAG not found, pulling latest"; \
		docker pull ghcr.io/liatoshynsky-foundation/lf-placeholder:latest; \
		docker tag ghcr.io/liatoshynsky-foundation/lf-placeholder:latest ghcr.io/liatoshynsky-foundation/lf-placeholder:$$PLACEHOLDER_TAG; \
	}
	@echo "$(GREEN)✓ Application images pulled$(NC)"

health-check: ## Perform health checks for services
	@echo "$(GREEN)Performing health checks...$(NC)"
	@echo "$(YELLOW)Waiting 15 seconds for admin...$(NC)" && sleep 15 && \
		docker exec lf-admin sh -c "wget -q -O- http://localhost:3001/ >/dev/null 2>&1 || curl -sf http://localhost:3001/ >/dev/null 2>&1" && \
		echo "$(GREEN)✓ admin health check passed$(NC)" || { \
			echo "$(RED)✗ admin health check failed$(NC)"; \
			docker logs --tail 30 lf-admin 2>&1 || true; \
			exit 1; \
		}
	@echo "$(YELLOW)Waiting 45 seconds for client...$(NC)" && sleep 45 && \
		docker exec lf-client sh -c "wget -q -O- http://localhost:3000/en >/dev/null 2>&1 || curl -sf http://localhost:3000/en >/dev/null 2>&1" && \
		echo "$(GREEN)✓ client health check passed$(NC)" || { \
			echo "$(RED)✗ client health check failed$(NC)"; \
			docker logs --tail 50 lf-client 2>&1 || true; \
			docker exec lf-client env | grep -E "MONGO_" || true; \
			exit 1; \
		}
	@echo "$(YELLOW)Waiting 10 seconds for placeholder...$(NC)" && sleep 10 && \
		docker exec lf-placeholder sh -c "wget -q -O- http://localhost/ >/dev/null 2>&1 || curl -sf http://localhost/ >/dev/null 2>&1" && \
		echo "$(GREEN)✓ placeholder health check passed$(NC)" || { \
			echo "$(RED)✗ placeholder health check failed$(NC)"; \
			docker logs --tail 30 lf-placeholder 2>&1 || true; \
			exit 1; \
		}
	@echo "$(GREEN)✓ All health checks passed$(NC)"

check-logs: ## Check logs for errors
	@echo "$(GREEN)Checking logs for errors...$(NC)"
	@for service in admin client lf-placeholder; do \
		if docker compose -f $(COMPOSE_FILE) logs $$service | tail -20 | grep -i "error\|fatal\|exception"; then \
			echo "$(RED)Errors found in $$service logs$(NC)"; \
			docker compose -f $(COMPOSE_FILE) logs $$service | tail -50; \
			exit 1; \
		fi; \
	done
	@echo "$(GREEN)✓ No errors found in logs$(NC)"

cleanup-images: ## Clean up old Docker images
	@echo "$(GREEN)Cleaning up old images...$(NC)"
	@docker image prune -f
	@echo "$(GREEN)✓ Cleanup completed$(NC)"

# Prevent Make from trying to build files with these names
%:
	@:

# Default command
.DEFAULT_GOAL := help
