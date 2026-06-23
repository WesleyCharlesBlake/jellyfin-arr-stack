SHELL := /bin/bash

COMPOSE ?= docker compose
PUID ?= 1000
PGID ?= 1000
TZ ?= Africa/Johannesburg
MEDIA_ROOT ?= /mnt/media
DOWNLOADS_ROOT ?= /mnt/downloads

.PHONY: help deps media-dirs media-dirs-prompt config up down ps logs

help:
	@printf '%s\n' \
		'Targets:' \
		'  make deps              Install Docker Engine and the Compose plugin on Ubuntu-based hosts' \
		'  make media-dirs        Create media/download folders using MEDIA_ROOT and DOWNLOADS_ROOT' \
		'  make media-dirs-prompt Prompt for media/download folders, then create them' \
		'  make config            Validate and render the Docker Compose config' \
		'  make up                Start the stack' \
		'  make down              Stop and remove stack containers' \
		'  make ps                Show stack status' \
		'  make logs              Follow stack logs' \
		'' \
		'Examples:' \
		'  make media-dirs' \
		'  make media-dirs MEDIA_ROOT=/mnt/storage/media DOWNLOADS_ROOT=/mnt/storage/downloads' \
		'  MEDIA_ROOT=/mnt/storage/media DOWNLOADS_ROOT=/mnt/storage/downloads make up'

deps:
	@set -euo pipefail; \
	if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then \
		echo 'Docker Engine and Docker Compose are already installed.'; \
		docker --version; \
		docker compose version; \
		exit 0; \
	fi; \
	if ! command -v apt-get >/dev/null 2>&1; then \
		echo 'This target supports Ubuntu-based apt hosts only.'; \
		exit 1; \
	fi; \
	sudo apt-get update; \
	sudo apt-get install -y ca-certificates curl gnupg; \
	sudo install -m 0755 -d /etc/apt/keyrings; \
	if [ ! -f /etc/apt/keyrings/docker.asc ]; then \
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null; \
	fi; \
	sudo chmod a+r /etc/apt/keyrings/docker.asc; \
	. /etc/os-release; \
	codename="$${UBUNTU_CODENAME:-$${VERSION_CODENAME:-}}"; \
	if [ -z "$$codename" ]; then \
		echo 'Could not detect the Ubuntu codename for the Docker apt repository.'; \
		exit 1; \
	fi; \
	architecture="$$(dpkg --print-architecture)"; \
	printf '%s\n' \
		'Types: deb' \
		'URIs: https://download.docker.com/linux/ubuntu' \
		"Suites: $$codename" \
		'Components: stable' \
		"Architectures: $$architecture" \
		'Signed-By: /etc/apt/keyrings/docker.asc' \
		| sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null; \
	sudo apt-get update; \
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; \
	sudo usermod -aG docker "$$USER"; \
	docker --version; \
	docker compose version; \
	echo 'Docker installed. Log out and back in for the docker group change to apply.'

media-dirs:
	@set -euo pipefail; \
	echo 'Creating media directories:'; \
	echo "  MEDIA_ROOT=$(MEDIA_ROOT)"; \
	echo "  DOWNLOADS_ROOT=$(DOWNLOADS_ROOT)"; \
	echo "  owner=$(PUID):$(PGID)"; \
	sudo mkdir -p "$(MEDIA_ROOT)/movies" "$(MEDIA_ROOT)/tv" "$(DOWNLOADS_ROOT)"; \
	sudo chown -R "$(PUID):$(PGID)" "$(MEDIA_ROOT)" "$(DOWNLOADS_ROOT)"; \
	echo 'Done.'

media-dirs-prompt:
	@set -euo pipefail; \
	read -r -p 'Media root [$(MEDIA_ROOT)]: ' media_root; \
	read -r -p 'Downloads root [$(DOWNLOADS_ROOT)]: ' downloads_root; \
	read -r -p 'Owner UID [$(PUID)]: ' puid; \
	read -r -p 'Owner GID [$(PGID)]: ' pgid; \
	media_root="$${media_root:-$(MEDIA_ROOT)}"; \
	downloads_root="$${downloads_root:-$(DOWNLOADS_ROOT)}"; \
	puid="$${puid:-$(PUID)}"; \
	pgid="$${pgid:-$(PGID)}"; \
	echo 'Creating media directories:'; \
	echo "  MEDIA_ROOT=$$media_root"; \
	echo "  DOWNLOADS_ROOT=$$downloads_root"; \
	echo "  owner=$$puid:$$pgid"; \
	sudo mkdir -p "$$media_root/movies" "$$media_root/tv" "$$downloads_root"; \
	sudo chown -R "$$puid:$$pgid" "$$media_root" "$$downloads_root"; \
	echo 'Done.'; \
	if [ "$$media_root" != '/mnt/media' ] || [ "$$downloads_root" != '/mnt/downloads' ]; then \
		echo ''; \
		echo 'Use the same paths when starting Compose:'; \
		echo "  MEDIA_ROOT=$$media_root DOWNLOADS_ROOT=$$downloads_root docker compose up -d"; \
	fi

config:
	$(COMPOSE) config

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f
