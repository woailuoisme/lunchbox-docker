# Makefile readme (en): <https://www.gnu.org/software/make/manual/html_node/index.html#SEC_Contents>

SHELL = /bin/bash
DC_RUN_ARGS = -f docker-compose.yml
HOST_UID=$(shell id -u)
HOST_GID=$(shell id -g)

# 默认配置变量
REGISTRY ?= jiaoio
IMAGE_NAME ?= php-base
PHP_VERSION ?= 8.4
TAG ?= latest
WWWGROUP ?= $(shell id -g)

include $(PWD)/.env
export

.PHONY : help up down shell\:php-fpm stop-all ps update build restart down-up images\:list images\:clean logs\:php-fpm logs containers\:health command\:php-fpm
.PHONY : php-build up-build php-restart php-logs compose-shell supervisor-start supervisor-status supervisor-reload nginx-reload nginx-restart nginx-check-restart remove-orphans php-recreate php-rebuild build-local build-multiarch slim-image push-image build-slim-push build-multiarch-slim clean-images show-config login-registry check-compose-files compose-validate check-tools check-php-fpm check-nginx check-postgres check-redis check-all check-containers check-all-services show-versions recreate cert check-caddy authelia-config-validate authelia-generate-password ssh-gen ssh-copy-id ssh ssh-a
.DEFAULT_GOAL : help

# Docker Compose 管理
up: ## Up containers
	docker compose ${DC_RUN_ARGS} up -d --remove-orphans

logs: ## Tail all containers logs
	docker compose ${DC_RUN_ARGS} logs -f

down: ## Stop containers
	docker compose ${DC_RUN_ARGS} down

down\:with-volumes: ## Stop containers and remove volumes
	docker compose ${DC_RUN_ARGS} down -v

shell\:php-fpm: ## Start shell into php-fpm container
	docker compose ${DC_RUN_ARGS} exec php-fpm sh

command\:php-fpm: ## Run a command in the php-fpm container
	docker compose ${DC_RUN_ARGS} exec php-fpm sh -c "$(command)"

stop-all: ## Stop all containers
	docker stop $(shell docker ps -a -q)

ps: ## Containers status with formatted output
	@echo "📊 Container Status:"
	@echo "=================="
	@docker compose ${DC_RUN_ARGS} ps --format "table {{.Name}}\t{{.Service}}\t{{.Status}}\t{{.Ports}}" | \
	awk ' \
		NR==1 {print "📋 " $$0; next} \
		/unhealthy/ {print "❌ " $$0; next} \
		/healthy/ {print "✅ " $$0; next} \
		{print "⚠️  " $$0} \
	'

kill-all: ## Force stop all containers (use only when all containers are unresponsive)
	docker kill $(shell docker ps -q)

supervisor-start: ## Start supervisord in running container
	@echo "🚀 Starting supervisord..."
	docker compose ${DC_RUN_ARGS} exec php-fpm supervisord -c /etc/supervisor/conf.d/supervisord.conf

supervisor-status: ## Check supervisord status
	@echo "📊 Checking supervisord status..."
	docker compose ${DC_RUN_ARGS} exec php-fpm sh -c 'export PYTHONWARNINGS="ignore::UserWarning:supervisor.options" && supervisorctl status'

supervisor-reload: ## Reload configuration and restart all processes
	@echo "🔄 Reloading supervisord configuration and restarting all processes..."
	docker compose ${DC_RUN_ARGS} exec php-fpm sh -c 'export PYTHONWARNINGS="ignore::UserWarning:supervisor.options" && supervisorctl reload'

nginx-check: ## Check Nginx configuration syntax
	@echo "🔍 Checking Nginx configuration syntax..."
	docker compose ${DC_RUN_ARGS} exec nginx nginx -t

nginx-reload: ## Reload Nginx configuration (without restarting container)
	@echo "🔄 Reloading Nginx configuration..."
	docker compose ${DC_RUN_ARGS} exec nginx nginx -s reload

nginx-restart: ## Restart Nginx service
	@echo "🔄 Restarting Nginx service..."
	docker compose ${DC_RUN_ARGS} restart nginx

nginx-check-restart: ## Check Nginx configuration and restart if valid
	@echo "🔍 Checking Nginx configuration and restarting..."
	@if docker compose ${DC_RUN_ARGS} exec nginx nginx -t; then \
		echo "✅ Nginx configuration check passed, restarting service..."; \
		docker compose ${DC_RUN_ARGS} restart nginx; \
		echo "✅ Nginx service restarted"; \
	else \
		echo "❌ Nginx configuration check failed, please check configuration files"; \
		exit 1; \
	fi