# Typical usages of make for this project are listed below.
# 	make				    : see `update-images`
#	make update-images	    : update the Talos and job images in the Azure Container Registry
#	make run-job		    : run a job in the Azure Container App using the latest Talos job image

ANSI_GREEN := \033[0;32m
ANSI_GREY := \033[0;90m
ANSI_BLUE := \033[0;36m
ANSI_RESET := \033[0;0m
.DEFAULT_GOAL := update-images

.PHONY: update-images
update-images: update-job-image
	@echo
	@echo "$(ANSI_GREEN)====== Done! ======$(ANSI_RESET)"

# Fill in Azure resource names from deployment info.
.PHONY: get-deployment-vars
get-deployment-vars:
	@echo "$(ANSI_GREY)Reading deployment variables from deploy/deployment.env...$(ANSI_RESET)"
	@bash -c 'set -o allexport; source deploy/deployment.env; set +o allexport'
ifndef DEPLOYMENT_NAME
	$(error DEPLOYMENT_NAME is not set)
endif
	@echo "$(ANSI_BLUE)DEPLOYMENT_NAME is $(DEPLOYMENT_NAME)$(ANSI_RESET)"
	$(eval DEPLOYMENT_ACR := $(DEPLOYMENT_NAME)acr)
	$(eval DEPLOYMENT_RG := $(DEPLOYMENT_NAME)-rg)

# Get the latest Talos version from the bumpversion config file in the submodule.
.PHONY: get-talos-version
get-talos-version:
	@echo "$(ANSI_GREY)Reading Talos version from talos/.bumpversion.cfg...$(ANSI_RESET)"
# $(eval TALOS_VERSION := $(shell grep -oP '(?<=current_version = ).*' talos/.bumpversion.cfg))
	$(eval TALOS_VERSION := 6.1.2)
	@echo "$(ANSI_BLUE)TALOS_VERSION is $(TALOS_VERSION)$(ANSI_RESET)"

.PHONY: acr-login
acr-login: get-deployment-vars
	az acr login --name $(DEPLOYMENT_ACR)

.PHONY: push-talos
push-talos: get-talos-version get-deployment-vars acr-login
	@echo "$(ANSI_GREY)Pushing Talos docker image...$(ANSI_RESET)"
	docker push $(DEPLOYMENT_ACR).azurecr.io/talos:$(TALOS_VERSION)

.PHONY: build-talos
build-talos: get-talos-version get-deployment-vars
	@echo "$(ANSI_GREY)Building Talos docker image...$(ANSI_RESET)"
	docker build -t talos:$(TALOS_VERSION) -f talos/Dockerfile talos/
	docker tag talos:$(TALOS_VERSION) $(DEPLOYMENT_ACR).azurecr.io/talos:$(TALOS_VERSION)

.PHONY: update-talos-image
update-talos-image: build-talos push-talos

.PHONY: build-job
build-job: get-talos-version get-deployment-vars
	@echo "$(ANSI_GREY)Building latest Talos run-job docker image...$(ANSI_RESET)"
	docker build --build-arg TALOS_BASE_IMAGE=${DEPLOYMENT_ACR}.azurecr.io/talos:$(TALOS_VERSION) -t talos-run:$(TALOS_VERSION) .
	docker tag talos-run:$(TALOS_VERSION) $(DEPLOYMENT_ACR).azurecr.io/talos-run:$(TALOS_VERSION)
	docker tag talos-run:$(TALOS_VERSION) $(DEPLOYMENT_ACR).azurecr.io/talos-run:latest

.PHONY: push-job
push-job: get-talos-version get-deployment-vars acr-login
	@echo "$(ANSI_GREY)Pushing latest Talos run-job docker image...$(ANSI_RESET)"
	docker push $(DEPLOYMENT_ACR).azurecr.io/talos-run:$(TALOS_VERSION)
	docker push $(DEPLOYMENT_ACR).azurecr.io/talos-run:latest

.PHONY: update-job-image
update-job-image: build-job push-job

.PHONY: run-job
run-job: get-talos-version get-deployment-vars
	az containerapp job start --name "talos-run" --resource-group $(DEPLOYMENT_RG) \
		--image $(DEPLOYMENT_ACR).azurecr.io/talos-run:$(TALOS_VERSION) \
		--command "/bin/bash" "/scripts/test_runner.sh" \
		--args "hello-world"
