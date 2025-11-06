# Setup ————————————————————————————————————————————————————————————————————————
# Target OS detection
ifeq ($(shell uname -s),Linux)
	# Config & environment variable on Linux
	SHELL			= bash
	DIR_SEPARATOR	= /
	USER			= $(shell id -u)
	GROUP			= $(shell id -g)
	SYMFONY_BIN		= symfony
	DOCKER_ENV		= USER_ID=$(USER) GROUP_ID=$(GROUP)
	DOCKER			= $(DOCKER_ENV) docker
	PURGE_CMD		= sudo rm -Rf
else
	$(error OS not supported by this Makefile)
endif

DOCKER_COMP		= $(DOCKER) compose
PHP				= $(SYMFONY_BIN) php
SYMFONY			= $(SYMFONY_BIN) console
COMPOSER		= $(SYMFONY_BIN) composer
PHPUNIT			= XDEBUG_MODE=coverage $(PHP) vendor/bin/phpunit -d memory_limit=-1 --stop-on-failure
.DEFAULT_GOAL	= help
.PHONY: $(filter-out vendor,$(MAKECMDGOALS))
# Default arguments values ————————————————————————————————————————————————————
env = dev

## —— THE Symfony Makefile 🍺 ——————————————————————————————————————————————————
help: ## Outputs this help screen
	@grep -E '(^[a-zA-Z0-9_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

## —— Project 🛠———————————————————————————————————————————————————————————————
install-up: docker-up composer-install assets

install: install-up docker-down ## Install requirements (create database, install php dependencies and build assets)

update: docker-pull composer-update ## Update requirements (Docker images & composer dependencies)

run: install-up symfony-start ## Start docker and start the web server

abort: symfony-stop docker-down ## Stop docker and the Symfony binary server

log: ## Show symfony log
	$(SYMFONY_BIN) server:log

security: ## Launch dependencies security check
	$(SYMFONY_BIN) check:security

requirements: ## Launch symfony requirements check
	$(SYMFONY_BIN) check:requirements

ci: security lint analyse tests ## Launch the ci locally

purge: ## Purge the dependencies
	sudo rm -Rf vendor/
	sudo rm -Rf var/cache/*
	sudo rm -Rf var/log/*

## —— Composer 🧙‍♂️ ————————————————————————————————————————————————————————————
vendor: composer.lock
	@if [ ! -d "vendor" ]; then \
		$(COMPOSER) install --no-progress --prefer-dist --optimize-autoloader; \
	else \
		echo "Vendor directory already exists. Skipping composer-install."; \
	fi

composer-install: vendor  ## Install vendors according to the current composer.lock file

composer-update: composer.json ## Update vendors according to the composer.json file
	$(COMPOSER) update

## —— Symfony 🎵 ———————————————————————————————————————————————————————————————
cc: ## Clear the cache. DID YOU CLEAR YOUR CACHE????
	$(SYMFONY) doctrine:cache:clear-metadata
	$(SYMFONY) doctrine:cache:clear-query
	$(SYMFONY) doctrine:cache:clear-result
	$(SYMFONY) cache:clear --env=$(env)

## —— Symfony binary 💻 ————————————————————————————————————————————————————————
cert-install: ## Install the local HTTPS certificates
	$(SYMFONY_BIN) server:ca:install

symfony-start: ## Serve the application with HTTPS support
	$(SYMFONY_BIN) serve --daemon

symfony-stop: ## Stop the web server
	$(SYMFONY_BIN) server:stop

## —— Docker 🐳 ————————————————————————————————————————————————————————————————
docker-up: compose.yaml ## Start the docker hub (MySQL,redis,phpmyadmin,mailcatcher)
	$(DOCKER_ENV) $(DOCKER_COMP) up -d --wait

docker-pull: compose.yaml ## Pull docker image (MySQL,redis,phpmyadmin,mailcatcher)
	$(DOCKER_ENV) $(DOCKER_COMP) pull

docker-down: compose.yaml ## Stop the docker hub
	$(DOCKER_ENV) $(DOCKER_COMP) down --remove-orphans

## —— CI: Tools ✅ —————————————————————————————————————————————————————————————
tools: composer-install ## Install CI tools
	$(COMPOSER) install -W -d tools/php-cs-fixer
	$(COMPOSER) install -W -d tools/phpstan

tools-pull: tools  ## Upgrade CI tools
	$(COMPOSER) upgrade -W -d tools/php-cs-fixer
	$(COMPOSER) upgrade -W -d tools/phpstan

## —— CI: Tests ✅ —————————————————————————————————————————————————————————————
tests: composer-install ## Run the PHPUnit tests
	$(PHPUNIT) --testdox --coverage-text

## —— CI: Coding standards ✨ ——————————————————————————————————————————————————
analyse: php-cs-fixer php-stan ## Run PHPCsFixer (PSR12, Symfony) & PHPStan

php-cs-fixer: tools ## Run PHPCsFixer (PSR12, Symfony)
	$(PHP) tools/php-cs-fixer/vendor/bin/php-cs-fixer fix --dry-run --diff

php-stan: tools ## Run PHPStan
	$(PHP) tools/phpstan/vendor/bin/phpstan analyse

## —— CI: Linter 🧯 ————————————————————————————————————————————————————————————
lint: lint-yaml lint-container lint-doctrine lint-composer lint-twig ## Run linters

lint-yaml: composer-install ## Lint YAML files
	$(SYMFONY) lint:yaml config --parse-tags

lint-container: composer-install ## Lint Parameters and Services
	$(SYMFONY) lint:container

lint-doctrine: composer-install ## Lint Doctrine mapping
	$(SYMFONY) doctrine:schema:validate --skip-sync -v --no-interaction

lint-composer: ## Lint Composer config
	$(COMPOSER) validate --strict

lint-twig: composer-install ## Run Twig Lint
	$(SYMFONY) lint:twig templates

## —— Database 📑 ——————————————————————————————————————————————————————————————
db-cache: ## Clear database metadata cache
	$(SYMFONY) doctrine:cache:clear-metadata --env=$(env)

db-create: db-cache ## Create the database
	$(SYMFONY) doctrine:database:create --if-not-exists --env=$(env)

db-drop-force: composer-install ## Force re-create the database
	$(SYMFONY) doctrine:database:drop --if-exists --force --env=$(env)

db-schema: db-create ## Update the database schema
	$(SYMFONY) doctrine:migrations:migrate --env=$(env) -q --allow-no-migration

db-fixtures: db-schema ## Load the fixtures from foundry
	$(SYMFONY) foundry:load main --env=$(env) -n

db-clean: ## Clean the database (drop, create and load schema)
	$(eval CONFIRM := $(shell read -p "Are you sure you want to cleanup the database? [y/N] " CONFIRM && echo $${CONFIRM:-N}))
	@if [ "$(CONFIRM)" = "y" ]; then \
		$(MAKE) db-drop-force; \
		$(MAKE) db-schema; \
	fi

db-reset: ## Drop, create & fill database with fixtures.
	$(eval CONFIRM := $(shell read -p "Are you sure you want to reset the database? [y/N] " CONFIRM && echo $${CONFIRM:-N}))
	@if [ "$(CONFIRM)" = "y" ]; then \
		$(MAKE) db-drop-force; \
		$(MAKE) db-schema; \
		$(MAKE) db-fixtures; \
	fi

## —— Assets 💄 ——————————————————————————————————————————————————————————
assets: composer-install ## Run AssetMapper to install assets
	$(SYMFONY) importmap:install

assets-prod: ## Run AssetMapper to compile production assets
	$(SYMFONY) asset-map:compile

asset-audit: ## Run vulnerability audit against the importmap
	$(SYMFONY) importmap:audit

## —— Translations 🏳️ ———————————————————————————————————————————————————
translation-extract: composer-install ## Extract translation from the source code
	$(SYMFONY) translation:extract --force --format yaml --sort ASC --as-tree 10 --no-fill --env=$(env) --domain messages en
	$(SYMFONY) translation:extract --force --format yaml --sort ASC --as-tree 10 --no-fill --env=$(env) --domain messages fr

## —— Tools 🧰 ———————————————————————————————————————————————————————————
open: docker-up symfony-start ## Open the project webinterface
	$(SYMFONY_BIN) open:local

open-coverage: symfony-start ## Open coverage report
	$(SYMFONY_BIN) open:local --path=/coverage/

open-mailer: docker-up symfony-start ## Open MailCatcher
	$(SYMFONY_BIN) open:local:webmail

open-phpmyadmin: docker-up symfony-start ## Open PHPMyAdmin
	$(SYMFONY_BIN) open:local:service phpmyadmin
