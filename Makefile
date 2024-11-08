# Typical usages of make for this project are listed below.
# 	make				    : see `update-images`
#	make update-images	    : update the Talos and VEP run images in the Azure Container Registry
#	make run-job		    : run a job in the Azure Container App using the latest Talos job image
include deploy/deployment.env

# docker build -t vep:release_110.1 -t talosacr.azurecr.io/vep:release_110.1 -f images/images/vep_110/Dockerfile .

ANSI_GREEN := \033[0;32m
ANSI_GREY := \033[0;90m
ANSI_BLUE := \033[0;36m
ANSI_RESET := \033[0;0m
.DEFAULT_GOAL := update-images

# update-vep-job-image
.PHONY: update-images
update-images: update-talos-job-image
	@echo
	@echo "$(ANSI_GREEN)====== Done! ======$(ANSI_RESET)"

# Fill in Azure resource names from deployment info. Variables are read from deploy/deployment.env.
.PHONY: get-deployment-vars
get-deployment-vars:
	@echo "$(ANSI_GREY)Building deployment variables from deploy/deployment.env...$(ANSI_RESET)"
ifndef DEPLOYMENT_NAME
	$(error DEPLOYMENT_NAME is not set - check deploy/deployment.env)
endif
ifndef DEPLOYMENT_SUBSCRIPTION
	$(error DEPLOYMENT_SUBSCRIPTION is not set - check deploy/deployment.env)
endif
	@echo "$(ANSI_BLUE)DEPLOYMENT_NAME is $(DEPLOYMENT_NAME)$(ANSI_RESET)"
	$(eval DEPLOYMENT_ACR := $(DEPLOYMENT_NAME)acr)
	$(eval DEPLOYMENT_RG := $(DEPLOYMENT_NAME)-rg)

# Get the latest Talos version from the bumpversion config file in the submodule.
.PHONY: get-talos-version
get-talos-version:
	@echo "$(ANSI_GREY)Reading Talos version from talos/.bumpversion.cfg...$(ANSI_RESET)"
	$(eval TALOS_VERSION := $(shell grep -oP '(?<=current_version = ).*' talos/.bumpversion.cfg))
	@echo "$(ANSI_BLUE)TALOS_VERSION is $(TALOS_VERSION)$(ANSI_RESET)"

.PHONY: acr-login
acr-login: get-deployment-vars
	az acr login --name $(DEPLOYMENT_ACR)

.PHONY: push-talos-job
push-talos-job: get-talos-version get-deployment-vars acr-login
	@echo "$(ANSI_GREY)Pushing latest Talos run-job docker image...$(ANSI_RESET)"
	docker push $(DEPLOYMENT_ACR).azurecr.io/talos-run:$(TALOS_VERSION)
	docker push $(DEPLOYMENT_ACR).azurecr.io/talos-run:latest

.PHONY: build-talos-job
build-talos-job: get-talos-version get-deployment-vars
	@echo "$(ANSI_GREY)Building latest Talos run-job docker image...$(ANSI_RESET)"
	docker build -t talos-run:$(TALOS_VERSION) -f talos-run.Dockerfile .
	docker tag talos-run:$(TALOS_VERSION) $(DEPLOYMENT_ACR).azurecr.io/talos-run:$(TALOS_VERSION)
	docker tag talos-run:$(TALOS_VERSION) $(DEPLOYMENT_ACR).azurecr.io/talos-run:latest

.PHONY: update-talos-job-image
update-talos-job-image: build-talos-job push-talos-job

.PHONY: run-job
run-job: get-talos-version get-deployment-vars
	az containerapp job start --name "talos-run" --resource-group $(DEPLOYMENT_RG) \
		--image $(DEPLOYMENT_ACR).azurecr.io/talos-run:$(TALOS_VERSION) \
		--subscription $(DEPLOYMENT_SUBSCRIPTION) \
		--command "/bin/bash" "/scripts/test_runner.sh" \
		--args "hello-world"
