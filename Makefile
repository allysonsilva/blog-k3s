# Sets the default goal to be used if no targets were specified on the command line
.DEFAULT_GOAL := help

ifneq ("$(wildcard .env)","")
include .env
export
endif

ifneq ("$(wildcard scripts/envs/deploy.env)","")
include scripts/envs/deploy.env
export
endif

k3s_path := $(shell realpath $(K3S_PATH))

uname_OS := $(shell uname -s)
user_UID := $(if $(USER_UID_SHELL),$(USER_UID_SHELL),$(shell id -u))
user_GID := $(if $(USER_GID_SHELL),$(USER_GID_SHELL),$(shell id -g))
current_uid ?= "${user_UID}:${user_GID}"

ifeq ($(uname_OS),Darwin)
	user_UID := 1001
	user_GID := 1001
endif

# Handling environment variables
app_full_path := $(if $(APP_PATH_SHELL),$(APP_PATH_SHELL),$(APP_PATH))

# Passing the >_ options option
options := $(if $(options),$(options),--env-file $(k3s_path)/.env)

# ==================================================================================== #
# HELPERS
# ==================================================================================== #

# internal functions
define message_failure
	"\033[1;31m ❌$(1)\033[0m"
endef

define message_success
	"\033[1;32m ✅$(1)\033[0m"
endef

define message_info
	"\033[0;34m❕$(1)\033[0m"
endef

# ==================================================================================== #
# DOCKER
# ==================================================================================== #

.PHONY: docker/config-env
docker/config-env:
	@cp -n .env.example .env || true
	@sed -i "/^# PWD/c\PWD=$(shell pwd)" .env
	@sed -i "/^# APP_PATH/c\APP_PATH=$(shell dirname -- `pwd`)" .env
	@sed -i "/# USER_UID=.*/c\USER_UID=$(user_UID)" .env
	@sed -i "/# USER_GID=.*/c\USER_GID=$(user_GID)" .env
	@sed -i "/^# CURRENT_UID/c\CURRENT_UID=${current_uid}" .env
	@cp ./mysql/.env.container ./mysql/.env
	@cp ./soketi/.env.container ./soketi/.env
	@echo
	@echo -e $(call message_success, Run \`make docker/config-env\` successfully executed)

.PHONY: k8s/general-config
k8s/general-config:
	$(shell ./scripts/env-to-file.sh --file=config.yaml | kubectl apply -f - 2&>/dev/null)
	@echo -e $(call message_success, Run \`k8s\/general-config\` successfully executed)

# make php/composer-install
.PHONY: php/composer-install
php/composer-install:
	@echo
	@echo -e $(call message_info, Installing PHP dependencies with Composer 🗂)
	@echo
	docker run \
		--rm \
		--tty \
		--interactive \
		--volume $(app_full_path):/app \
		--workdir /app \
		$(options) \
		composer:2.5 \
			install \
				--optimize-autoloader \
				--ignore-platform-reqs \
				--prefer-dist \
				--ansi \
				--no-dev \
				--no-interaction

.PHONY: docker/app/pull
docker/app/pull:
	@echo
	@echo -e $(call message_info, Pull an image APP... 🏗)
	@echo
	docker pull ${APP_CONTAINER_IMAGE}

.PHONY: docker/app/build
docker/app/build:
	@echo
	@echo -e $(call message_info, Build an image APP... 🏗)
	@echo
	docker buildx build \
		--progress=plain \
		--target main \
		--platform linux/amd64,linux/arm64 \
		--cache-from ${APP_CONTAINER_REPO}:vendor \
		--cache-from ${APP_CONTAINER_REPO}:frontend \
		--cache-from ${APP_CONTAINER_REPO}:dependencies \
		--cache-from ${APP_CONTAINER_REPO}:latest \
		--tag ${APP_CONTAINER_IMAGE} \
		--file ${APP_BUILD_CONTAINER_PATH}/Dockerfile \
		--build-arg USER_UID=${USER_UID} \
		--build-arg USER_GID=${USER_GID} \
		--build-arg K3S_FOLDER=${K3S_FOLDER} \
		--build-arg APP_CONTAINER_REPO=${APP_CONTAINER_REPO} \
	${APP_PATH}

.PHONY: docker/app/push
docker/app/push:
	@echo
	@echo -e $(call message_info, Push Docker Image [BLOG] 🐳)
	@echo
	docker push ${APP_CONTAINER_IMAGE}

.PHONY: docker/app/dependencies/pull
docker/app/dependencies/pull:
	@echo
	@echo -e $(call message_info, Pull 🚚 Docker Image [DEPENDENCIES] 🐳)
	@echo
	docker pull ${APP_CONTAINER_REPO}:dependencies

.PHONY: docker/app/dependencies/build
docker/app/dependencies/build: $(eval SHELL:=/bin/bash)
	@echo
	@echo -e $(call message_info, Creating the [DEPENDENCIES] image of the application 🏗)
	@echo
	@CACHE_FROM="--cache-from ${APP_CONTAINER_REPO}:dependencies"; \
	if [ "$${no_cache_from:-false}" = "true" ]; then \
		CACHE_FROM="" ; \
	fi ; \
	docker buildx build \
		--progress=plain \
		--target dependencies \
		--platform linux/amd64,linux/arm64 \
		$$CACHE_FROM \
		--tag ${APP_CONTAINER_REPO}:dependencies \
		--file ${APP_BUILD_CONTAINER_PATH}/Dockerfile \
	${APP_PATH}

.PHONY: docker/app/dependencies/push
docker/app/dependencies/push:
	@echo
	@echo -e $(call message_info, Push 📦 an image [DEPENDENCIES] 🐳)
	@echo
	docker push ${APP_CONTAINER_REPO}:dependencies

.PHONY: docker/app/vendor/pull
docker/app/vendor/pull:
	@echo
	@echo -e $(call message_info, Pull 🚚 Docker Image [VENDOR] 🐳)
	@echo
	docker pull ${APP_CONTAINER_REPO}:vendor

.PHONY: docker/app/vendor/build
docker/app/vendor/build: $(eval SHELL:=/bin/bash)
	@echo
	@echo -e $(call message_info, Creating the [VENDOR] image of the application 🏗)
	@echo
	@CACHE_FROM="--cache-from ${APP_CONTAINER_REPO}:vendor"; \
	if [ "$${no_cache_from:-false}" = "true" ]; then \
		CACHE_FROM="" ; \
	fi ; \
	docker buildx build \
		--progress=plain \
		--target vendor \
		--platform linux/amd64,linux/arm64 \
		$$CACHE_FROM \
		--tag ${APP_CONTAINER_REPO}:vendor \
		--file ${APP_BUILD_CONTAINER_PATH}/Dockerfile \
	${APP_PATH}

.PHONY: docker/app/vendor/push
docker/app/vendor/push:
	@echo
	@echo -e $(call message_info, Push 📦 an image [VENDOR] 🐳)
	@echo
	docker push ${APP_CONTAINER_REPO}:vendor

.PHONY: docker/app/frontend/pull
docker/app/frontend/pull:
	@echo
	@echo -e $(call message_info, Pull 🚚 Docker Image [FRONTEND] 🐳)
	@echo
	docker pull ${APP_CONTAINER_REPO}:frontend

.PHONY: docker/app/frontend/build
docker/app/frontend/build: $(eval SHELL:=/bin/bash)
	@echo
	@echo -e $(call message_info, Creating the [FRONT-END] image of the application 🏗)
	@echo
	@CACHE_FROM="--cache-from ${APP_CONTAINER_REPO}:frontend"; \
	if [ "$${no_cache_from:-false}" = "true" ]; then \
		CACHE_FROM="" ; \
	fi ; \
	DOCKER_BUILDKIT=1 docker build \
		--progress=plain \
		--target frontend \
		--platform linux/amd64,linux/arm64 \
		$$CACHE_FROM \
		--tag ${APP_CONTAINER_REPO}:frontend \
		--file ${APP_BUILD_CONTAINER_PATH}/Dockerfile \
	${APP_PATH}

.PHONY: docker/app/frontend/push
docker/app/frontend/push:
	@echo
	@echo -e $(call message_info, Push 📦 an image [FRONTEND] 🐳)
	@echo
	docker push ${APP_CONTAINER_REPO}:frontend

.PHONY: argo/rollouts/install
argo/rollouts/install:
	@echo
	@echo -e $(call message_info, Installing Argo Rollouts 🏗️)
	@echo
	kubectl apply -f argo/rollouts/namespace.yaml
	@echo
	./scripts/env-to-file.sh --file=argo/rollouts/application-helm.yaml | kubectl apply -f -
	@echo
	./scripts/env-to-file.sh --file=argo/rollouts/ingress.yaml | kubectl apply -f -
