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
runtime: push-talos build-run-image
	@echo
	@echo "$(ANSI_GREEN)====== Done! ======$(ANSI_RESET)"

.PHONY: push-talos
push-talos: build-talos get-talos-version check-env acr-login
	@echo "pushing talos docker image"
	docker push $(DEPLOYMENT_ACR).azurecr.io/talos:$(TALOS_VERSION)

.PHONY: build-talos
build-talos: get-talos-version check-env
	@echo "building talos docker image"
	# docker build --build-arg cloud=none -t talos:$(TALOS_VERSION) -f talos/Dockerfile talos/
	docker build -t talos:$(TALOS_VERSION) -f talos/Dockerfile talos/
	docker tag talos:$(TALOS_VERSION) $(DEPLOYMENT_ACR).azurecr.io/talos:$(TALOS_VERSION)

.PHONY: build-run-image
build-run-image: get-talos-version check-env
	docker build --build-arg TALOS_BASE_IMAGE=${DEPLOYMENT_ACR}.azurecr.io/talos:$(TALOS_VERSION) -t talos-run:$(TALOS_VERSION) .
	docker tag talos-run:$(TALOS_VERSION) $(DEPLOYMENT_ACR).azurecr.io/talos-run:$(TALOS_VERSION)
	docker tag talos-run:$(TALOS_VERSION) $(DEPLOYMENT_ACR).azurecr.io/talos-run:latest
	docker push $(DEPLOYMENT_ACR).azurecr.io/talos-run:$(TALOS_VERSION)
	docker push $(DEPLOYMENT_ACR).azurecr.io/talos-run:latest

.PHONY: run-job
run-job: get-talos-version check-env
	az containerapp job start --name "talos-run" --resource-group $(DEPLOYMENT_RG) \
		--image $(DEPLOYMENT_ACR).azurecr.io/talos-run:$(TALOS_VERSION) \
		--command "/bin/bash" \
		--args "/scripts/test_runner.sh" "hello-world"

get-talos-version:
# $(eval TALOS_VERSION := $(shell grep -oP '(?<=current_version = ).*' talos/.bumpversion.cfg))
	$(eval TALOS_VERSION := 6.1.2)
	@echo "TALOS_VERSION is $(TALOS_VERSION)"

.PHONY: check-env
check-env:
ifndef DEPLOYMENT_NAME
	$(error DEPLOYMENT_NAME is not set)
endif
	$(eval DEPLOYMENT_ACR := $(DEPLOYMENT_NAME)acr)
	$(eval DEPLOYMENT_RG := $(DEPLOYMENT_NAME)-rg)

.PHONY: acr-login
acr-login: check-env
	az acr login --name $(DEPLOYMENT_ACR)