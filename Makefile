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
push-talos: build-talos get-talos-version check-env acr-login
	@echo "pushing talos docker image"
	docker push $(DEPLOYMENT_ACR).azurecr.io/talos:$(TALOS_VERSION)

.PHONY: push-talos-deploy
push-talos-deploy: build-talos-deploy get-talos-version check-env acr-login
	@echo "pushing talos-deploy docker image"
	docker push $(DEPLOYMENT_ACR).azurecr.io/talos-deploy:$(TALOS_VERSION)

.PHONY: build-talos
build-talos: get-talos-version check-env
	@echo "buliding talos docker image"
	# docker build --build-arg cloud=none -t talos:$(TALOS_VERSION) -f talos/Dockerfile talos/
	docker build -t talos:$(TALOS_VERSION) -f talos/Dockerfile talos/
	docker tag talos:$(TALOS_VERSION) $(DEPLOYMENT_ACR).azurecr.io/talos:$(TALOS_VERSION)

.PHONY: build-talos-deploy
build-talos-deploy: get-talos-version check-env
	@echo "building talos-deploy docker image"
	docker build --build-arg TALOS_VERSION=$(TALOS_VERSION) -t talos-deploy:$(TALOS_VERSION) .	
	docker tag talos-deploy:$(TALOS_VERSION) $(DEPLOYMENT_ACR).azurecr.io/talos-deploy:$(TALOS_VERSION)

get-talos-version:
	$(eval TALOS_VERSION := $(shell grep -oP '(?<=current_version = ).*' talos/.bumpversion.cfg))
	@echo "TALOS_VERSION is $(TALOS_VERSION)"

.PHONY: check-env
check-env:
ifndef DEPLOYMENT_ACR
	$(error DEPLOYMENT_ACR is not set)
endif

.PHONY: acr-login
acr-login:
	az acr login --name $(DEPLOYMENT_ACR)