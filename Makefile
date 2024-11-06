# Typical usages of make for this project are listed below.
# 	make				    : see `update-images`
#	make update-images	    : update the Talos and job images in the Azure Container Registry
#	make run-job		    : run a job in the Azure Container App using the latest Talos job image

ANSI_GREEN := \033[0;32m
ANSI_GREY := \033[0;37m
ANSI_RESET := \033[0;0m
.DEFAULT_GOAL := update-images

.PHONY: update-images
update-images: update-talos-image update-job-image
	@echo
	@echo "$(ANSI_GREEN)====== Done! ======$(ANSI_RESET)"

# Fill in Azure resource names from deployment info.
.PHONY: get-deployment-vars
get-deployment-vars:
	@echo "Reading deployment variables from deploy/deployment.env"
	@bash -c 'set -o allexport; source deploy/deployment.env; set +o allexport'
ifndef DEPLOYMENT_NAME
	$(error DEPLOYMENT_NAME is not set)
endif
	$(eval DEPLOYMENT_ACR := $(DEPLOYMENT_NAME)acr)
	$(eval DEPLOYMENT_RG := $(DEPLOYMENT_NAME)-rg)

# Get the latest Talos version from the bumpversion config file in the submodule.
.PHONY: get-talos-version
get-talos-version:
# $(eval TALOS_VERSION := $(shell grep -oP '(?<=current_version = ).*' talos/.bumpversion.cfg))
	$(eval TALOS_VERSION := 6.1.2)
	@echo "TALOS_VERSION is $(TALOS_VERSION)"

.PHONY: acr-login
acr-login: get-deployment-vars
	az acr login --name $(DEPLOYMENT_ACR)

.PHONY: push-talos
push-talos: get-talos-version get-deployment-vars acr-login
	@echo "pushing talos docker image"
	docker push $(DEPLOYMENT_ACR).azurecr.io/talos:$(TALOS_VERSION)

.PHONY: build-talos
build-talos: get-talos-version get-deployment-vars
	@echo "Building Talos docker image"
	# docker build --build-arg cloud=none -t talos:$(TALOS_VERSION) -f talos/Dockerfile talos/
	docker build -t talos:$(TALOS_VERSION) -f talos/Dockerfile talos/
	docker tag talos:$(TALOS_VERSION) $(DEPLOYMENT_ACR).azurecr.io/talos:$(TALOS_VERSION)

.PHONY: update-talos-image
update-talos-image: build-talos push-talos

.PHONY: build-job
build-job: get-talos-version get-deployment-vars
	@echo "Building latest Talos run-job docker image"
	docker build --build-arg TALOS_BASE_IMAGE=${DEPLOYMENT_ACR}.azurecr.io/talos:$(TALOS_VERSION) -t talos-run:$(TALOS_VERSION) .
	docker tag talos-run:$(TALOS_VERSION) $(DEPLOYMENT_ACR).azurecr.io/talos-run:$(TALOS_VERSION)
	docker tag talos-run:$(TALOS_VERSION) $(DEPLOYMENT_ACR).azurecr.io/talos-run:latest

.PHONY: push-job
push-job: get-talos-version get-deployment-vars acr-login
	@echo "Pushing latest Talos run-job docker image"
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
