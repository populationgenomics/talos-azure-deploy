# Typical usages of make for this project are listed below.
# 	make				    : see `make runtime`
#	make runtime		    : build and push all docker images
#	make push-talos		    : push the talos docker image
#   make push-talos-deploy  : push the talos-deploy docker image
#   make build-talos	    : build the talos docker image
#   make build-talos-deploy : build the talos-deploy docker image

ANSI_GREEN := \033[0;32m
ANSI_RESET := \033[0;0m

.DEFAULT_GOAL := runtime
.PHONY: runtime
runtime: push-talos push-talos-deploy
	@echo
	@echo "$(ANSI_GREEN)====== Done! ======$(ANSI_RESET)"

.PHONY: push-talos
push-talos: build-talos
	@echo "az acr push or whatever"

.PHONY: push-talos-deploy
push-talos: build-talos-deploy
	@echo "az acr push or whatever"

.PHONY: build-talos
build-talos:
	@echo "docker build -t talos ."

.PHONY: build-talos-deploy
build-talos-deploy:
	@echo "docker build -t talos-deploy ."