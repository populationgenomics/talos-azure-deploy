# Typical usages of make for this project are listed below.
# 	make				    : see `update-images`
#	make update-images	    : update the Talos and VEP run images in the Azure Container Registry
#   make run-talos-job      : run a talos_runner job in the Azure Container Env using the latest Talos job image (DATASET_ID=<id>)
#   make run-vep-job        : run a vep_runner job in the Azure Container Env using the latest VEP job image (DATASET_ID=<id>)
#   make mount-all          : mount the data and reference shares locally
#   make unmount-all        : unmount/delete the local data and reference shares
#   make mount-share        : mount a specific share locally (SHARE_NAME=<share>)
include deploy/deployment.env

ANSI_GREEN := \033[0;32m
ANSI_GREY := \033[0;90m
ANSI_BLUE := \033[0;36m
ANSI_RESET := \033[0;0m

.DEFAULT_GOAL := update-images
SHARE_NAME ?= data

.PHONY: update-images
update-images: update-talos-job update-vep-job
	@echo
	@echo "$(ANSI_GREEN)====== Done! ======$(ANSI_RESET)"

#################
### UTILS
.PHONY: get-deployment-vars
get-deployment-vars:
ifndef DEPLOYMENT_NAME
	$(error DEPLOYMENT_NAME is not set - check deploy/deployment.env)
endif
ifndef DEPLOYMENT_SUBSCRIPTION
	$(error DEPLOYMENT_SUBSCRIPTION is not set - check deploy/deployment.env)
endif
	@echo "$(ANSI_BLUE)DEPLOYMENT_NAME is $(DEPLOYMENT_NAME)$(ANSI_RESET)"
	$(eval DEPLOYMENT_RG := $(DEPLOYMENT_NAME)-rg)
	$(eval DEPLOYMENT_STORAGE := $(DEPLOYMENT_NAME)sa)
	$(eval DEPLOYMENT_ACR := $(DEPLOYMENT_NAME)acr.azurecr.io)

# Write deployment variables to a TFVARS file for use in Terraform operations.
deploy-config: get-deployment-vars deploy/config.auto.tfvars
deploy/config.auto.tfvars:
	@echo "tenant_id = \"$(DEPLOYMENT_TENANT)\"" > deploy/config.auto.tfvars
	@echo "subscription_id = \"$(DEPLOYMENT_SUBSCRIPTION)\"" >> deploy/config.auto.tfvars
	@echo "deployment_name = \"$(DEPLOYMENT_NAME)\"" >> deploy/config.auto.tfvars
	@echo "region = \"$(DEPLOYMENT_REGION)\"" >> deploy/config.auto.tfvars
	@echo "$(ANSI_GREEN)Deployment variables written to deploy/config.auto.tfvars$(ANSI_RESET)"

# Get the latest Talos version from the bumpversion config file in the submodule.
# Use that as the version for talos-deploy.
.PHONY: get-td-version
get-td-version:
	@echo "$(ANSI_GREY)Reading Talos version from talos/.bumpversion.cfg...$(ANSI_RESET)"
	$(eval TD_VERSION := $(shell grep -oP '(?<=current_version = ).*' talos/.bumpversion.cfg))
	@echo "$(ANSI_BLUE)TD_VERSION is $(TD_VERSION)$(ANSI_RESET)"

.PHONY: acr-login
acr-login: get-deployment-vars
	az acr login --name $(DEPLOYMENT_ACR) --subscription $(DEPLOYMENT_SUBSCRIPTION)

.PHONY: get-job-status
get-job-status: get-deployment-vars
ifndef JOB_EXECUTION_NAME
	az containerapp job execution list -n "job-runner" -g "talosmsr01-rg" --subscription $(DEPLOYMENT_SUBSCRIPTION) \
	--query '[].{Name: name, StartTime: properties.startTime, Status: properties.status}' --output table
else
	az containerapp job execution show -n job-runner -g $(DEPLOYMENT_RG) --subscription $(DEPLOYMENT_SUBSCRIPTION) \
	--job-execution-name $(JOB_EXECUTION_NAME) --output table
endif

#################
### TALOS JOB
.PHONY: push-talos-job
push-talos-job: get-td-version get-deployment-vars acr-login
	@echo "$(ANSI_GREY)Pushing latest talos-run docker image...$(ANSI_RESET)"
	docker push $(DEPLOYMENT_ACR)/talos-run:$(TD_VERSION)
	docker push $(DEPLOYMENT_ACR)/talos-run:latest

.PHONY: build-talos-job
build-talos-job: get-td-version get-deployment-vars
	@echo "$(ANSI_GREY)Building latest talos-run docker image...$(ANSI_RESET)"
	docker build -t talos-run:$(TD_VERSION) -f docker/talos-run.Dockerfile .
	docker tag talos-run:$(TD_VERSION) $(DEPLOYMENT_ACR)/talos-run:$(TD_VERSION)
	docker tag talos-run:$(TD_VERSION) $(DEPLOYMENT_ACR)/talos-run:latest

.PHONY: update-talos-job
update-talos-job: build-talos-job push-talos-job

.PHONY: run-talos-job
run-talos-job: update-talos-job get-deployment-vars get-td-version
	az containerapp job start -n "job-runner" -g $(DEPLOYMENT_RG) --subscription $(DEPLOYMENT_SUBSCRIPTION) \
		--image $(DEPLOYMENT_ACR)/talos-run:$(TD_VERSION) --cpu 8.0 --memory 32.0Gi \
		--command "/bin/bash" "/scripts/talos_runner.sh" $(DATASET_ID)

#################
### VEP JOB
.PHONY: push-vep-job
push-vep-job: get-td-version get-deployment-vars acr-login
	@echo "$(ANSI_GREY)Pushing latest vep-run docker image...$(ANSI_RESET)"
	docker push $(DEPLOYMENT_ACR)/vep-run:$(TD_VERSION)
	docker push $(DEPLOYMENT_ACR)/vep-run:latest

.PHONY: build-vep-job
build-vep-job: build-vep-base-image get-td-version get-deployment-vars
	@echo "$(ANSI_GREY)Building latest vep-run docker image...$(ANSI_RESET)"
	docker build -t vep-run:$(TD_VERSION) -f docker/vep-run.Dockerfile .
	docker tag vep-run:$(TD_VERSION) $(DEPLOYMENT_ACR)/vep-run:$(TD_VERSION)
	docker tag vep-run:$(TD_VERSION) $(DEPLOYMENT_ACR)/vep-run:latest

.PHONY: build-vep-base-image
build-vep-base-image: 
	@echo "$(ANSI_GREY)Building latest VEP base docker image...$(ANSI_RESET)"
	docker build -t vep:release_110.1 -f images/images/vep_110/Dockerfile images/images/vep_110

.PHONY: update-vep-job
update-vep-job: build-vep-job push-vep-job

.PHONY: run-vep-job
run-vep-job: update-vep-job get-deployment-vars get-td-version
	az containerapp job start -n "job-runner" -g $(DEPLOYMENT_RG) --subscription $(DEPLOYMENT_SUBSCRIPTION) \
		--image $(DEPLOYMENT_ACR)/vep-run:$(TD_VERSION) --cpu 8.0 --memory 32.0Gi \
		--command "/bin/bash" "/scripts/vep_runner.sh" $(DATASET_ID)

#################
### REFERENCE JOB

.PHONY: run-reference-job
run-reference-job: update-vep-job get-deployment-vars get-td-version
	az containerapp job start -n "job-runner" -g $(DEPLOYMENT_RG) --subscription $(DEPLOYMENT_SUBSCRIPTION) \
		--image $(DEPLOYMENT_ACR)/vep-run:$(TD_VERSION) --command "/bin/bash" "/scripts/reference_runner.sh"

.PHONY: run-reference-job-local
run-reference-job-local: get-deployment-vars get-td-version
	docker run -it --mount type=bind,source=$(shell pwd)/.reference,target=/reference \
		vep-run:$(TD_VERSION) /bin/bash /scripts/reference_runner.sh

#################
### MOUNTS
.PHONY: mount-all
mount-all:
	$(MAKE) mount-share SHARE_NAME=data
	$(MAKE) mount-share SHARE_NAME=reference

.PHONY: unmount-all
unmount-all:
	$(MAKE) unmount-share SHARE_NAME=data
	$(MAKE) unmount-share SHARE_NAME=reference

.PHONY: mount-share
mount-share: get-deployment-vars
ifeq ($(SHARE_NAME),data)
else ifeq ($(SHARE_NAME),reference)
else
	@echo "Error: SHARE_NAME must be set to 'data' or 'reference'."
	exit 1
endif
	mkdir ./.$(SHARE_NAME)
	@echo "$(ANSI_GREY)Fetching storage key and mounting $(SHARE_NAME) share locally...$(ANSI_RESET)"
	STORAGE_KEY=$$(az storage account keys list -g $(DEPLOYMENT_RG) --account-name $(DEPLOYMENT_STORAGE) --subscription $(DEPLOYMENT_SUBSCRIPTION) --query "[0].value" --output tsv | tr -d '"') && \
	sudo mount -t cifs //$(DEPLOYMENT_STORAGE).file.core.windows.net/$(SHARE_NAME) ./.$(SHARE_NAME) \
		-o vers=3.1.1,username=$(DEPLOYMENT_STORAGE),password=$$STORAGE_KEY,dir_mode=0777,file_mode=0777
	@echo "$(ANSI_GREEN)Successfully mounted $(ANSI_RESET)./.$(SHARE_NAME)"

.PHONY: unmount-share
unmount-share:
	@echo "$(ANSI_GREY)Unmounting $(SHARE_NAME) share...$(ANSI_RESET)"
	sudo umount ./.$(SHARE_NAME) && rmdir ./.$(SHARE_NAME)
	@echo "$(ANSI_GREEN)Successfully unmounted $(ANSI_RESET)./.$(SHARE_NAME)"
