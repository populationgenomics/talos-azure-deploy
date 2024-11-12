# Typical usages of make for this project are listed below.
# 	make				    : see `update-images`
#	make update-images	    : update the Talos and VEP run images in the Azure Container Registry
#	make run-test-job		    : run a job in the Azure Container App using the latest Talos job image
include deploy/deployment.env

# docker build -t vep:release_110.1 -t talosacr.azurecr.io/vep:release_110.1 -f images/images/vep_110/Dockerfile .

ANSI_GREEN := \033[0;32m
ANSI_GREY := \033[0;90m
ANSI_BLUE := \033[0;36m
ANSI_RESET := \033[0;0m
.DEFAULT_GOAL := update-images

# update-vep-job
.PHONY: update-images
update-images: update-talos-job
	@echo
	@echo "$(ANSI_GREEN)====== Done! ======$(ANSI_RESET)"

# Fill in Azure resource names from deployment info. Variables are read from deploy/deployment.env.
.PHONY: get-deployment-vars
get-deployment-vars:
ifndef DEPLOYMENT_NAME
	$(error DEPLOYMENT_NAME is not set - check deploy/deployment.env)
endif
ifndef DEPLOYMENT_SUBSCRIPTION
	$(error DEPLOYMENT_SUBSCRIPTION is not set - check deploy/deployment.env)
endif
	@echo "$(ANSI_BLUE)DEPLOYMENT_NAME is $(DEPLOYMENT_NAME)$(ANSI_RESET)"
	$(eval DEPLOYMENT_ACR := $(DEPLOYMENT_NAME)acr)
	$(eval DEPLOYMENT_RG := $(DEPLOYMENT_NAME)-rg)
	$(eval DEPLOYMENT_STORAGE := $(DEPLOYMENT_NAME)sa)

# Get the latest Talos version from the bumpversion config file in the submodule.
# Use that as the version for talos-deploy.
.PHONY: get-td-version
get-td-version:
	@echo "$(ANSI_GREY)Reading Talos version from talos/.bumpversion.cfg...$(ANSI_RESET)"
	$(eval TD_VERSION := $(shell grep -oP '(?<=current_version = ).*' talos/.bumpversion.cfg))
	@echo "$(ANSI_BLUE)TD_VERSION is $(TD_VERSION)$(ANSI_RESET)"

.PHONY: acr-login
acr-login: get-deployment-vars
	az acr login --name $(DEPLOYMENT_ACR)

#################
### TALOS JOB
.PHONY: push-talos-job
push-talos-job: get-td-version get-deployment-vars acr-login
	@echo "$(ANSI_GREY)Pushing latest talos-run docker image...$(ANSI_RESET)"
	docker push $(DEPLOYMENT_ACR).azurecr.io/talos-run:$(TD_VERSION)
	docker push $(DEPLOYMENT_ACR).azurecr.io/talos-run:latest

.PHONY: build-talos-job
build-talos-job: get-td-version get-deployment-vars
	@echo "$(ANSI_GREY)Building latest talos-run docker image...$(ANSI_RESET)"
	docker build -t talos-run:$(TD_VERSION) -f docker/talos-run.Dockerfile .
	docker tag talos-run:$(TD_VERSION) $(DEPLOYMENT_ACR).azurecr.io/talos-run:$(TD_VERSION)
	docker tag talos-run:$(TD_VERSION) $(DEPLOYMENT_ACR).azurecr.io/talos-run:latest

.PHONY: update-talos-job
update-talos-job: build-talos-job push-talos-job

.PHONY: run-talos-job
run-talos-job: update-talos-job get-deployment-vars get-td-version
	docker run -it --mount type=bind,source=/home/azureuser/talos-deploy/.reference,target=/talos-deploy/reference --mount type=bind,source=/home/azureuser/talos-deploy/.data,target=/talos-deploy/data talos-run:$(TD_VERSION) /bin/bash /scripts/talos_runner.sh

	# az containerapp job start --name "talos-run" --resource-group $(DEPLOYMENT_RG) \
	# 	--image $(DEPLOYMENT_ACR).azurecr.io/talos-run:$(TD_VERSION) \
	# 	--subscription $(DEPLOYMENT_SUBSCRIPTION) \
	# 	--command "/bin/bash" "/scripts/talos_runner.sh" \
	# 	--args "/talos-deploy/data/output/annotated.vcf.bgz" "/talos-deploy/data/input/pedigree.ped"

#################
### VEP JOB
.PHONY: push-vep-job
push-vep-job: get-td-version get-deployment-vars acr-login
	@echo "$(ANSI_GREY)Pushing latest vep-run docker image...$(ANSI_RESET)"
	docker push $(DEPLOYMENT_ACR).azurecr.io/vep-run:$(VEP_VERSION)
	docker push $(DEPLOYMENT_ACR).azurecr.io/vep-run:latest

.PHONY: build-vep-job
build-vep-job: build-vep-base-image get-td-version get-deployment-vars
	@echo "$(ANSI_GREY)Building latest vep-run docker image...$(ANSI_RESET)"
	docker build -t vep-run:$(TD_VERSION) -f docker/vep-run.Dockerfile .
	docker tag vep-run:$(TD_VERSION) $(DEPLOYMENT_ACR).azurecr.io/vep-run:$(TD_VERSION)
	docker tag vep-run:$(TD_VERSION) $(DEPLOYMENT_ACR).azurecr.io/vep-run:latest

.PHONY: build-vep-base-image
build-vep-base-image: 
	@echo "$(ANSI_GREY)Building latest VEP base docker image...$(ANSI_RESET)"
	docker build -t vep:release_110.1 -f images/images/vep_110/Dockerfile images/images/vep_110

.PHONY: update-vep-job
update-vep-job: build-vep-job push-vep-job

.PHONY: run-vep-job
run-vep-job: update-vep-job get-deployment-vars get-td-version
	docker run -it --mount type=bind,source=/home/azureuser/talos-deploy/.reference,target=/talos-deploy/reference --mount type=bind,source=/home/azureuser/talos-deploy/.data,target=/talos-deploy/data vep-run:$(TD_VERSION) /bin/bash scripts/vep_runner.sh

	# az containerapp job start --name "vep-run" --resource-group $(DEPLOYMENT_RG) \
	# 	--image $(DEPLOYMENT_ACR).azurecr.io/vep-run:$(TD_VERSION) \
	# 	--subscription $(DEPLOYMENT_SUBSCRIPTION) \
	# 	--command "/bin/bash" "/scripts/vep_runner.sh"
	# 	--args "/talos-deploy/data/input/input.vcf.bgz"

.PHONY: run-references-job
run-references-job: update-talos-job get-deployment-vars get-td-version
	docker run -it --mount type=bind,source=/home/azureuser/talos-deploy/.reference2,target=/talos-deploy/reference talos-run:$(TD_VERSION) /bin/bash /scripts/references_runner.sh

	# az containerapp job start --name "references-run" --resource-group $(DEPLOYMENT_RG) \
	# 	--image $(DEPLOYMENT_ACR).azurecr.io/talos-run:$(TD_VERSION) \
	# 	--subscription $(DEPLOYMENT_SUBSCRIPTION) \
	# 	--command "/bin/bash" "/scripts/references_runner.sh"

.PHONY: run-test-job
run-test-job: get-td-version get-deployment-vars
	az containerapp job start --name "talos-run" --resource-group $(DEPLOYMENT_RG) \
		--image $(DEPLOYMENT_ACR).azurecr.io/talos-run:$(TD_VERSION) \
		--subscription $(DEPLOYMENT_SUBSCRIPTION) \
		--command "/bin/bash" "/scripts/test_runner.sh" \
		--args "hello-world"

.share-creds: get-deployment-vars
	STORAGE_ACCOUNT_KEY=$(az storage account keys list \
		--resource-group $(DEPLOYMENT_RG)
		--account-name $(DEPLOYMENT_STORAGE) \
		--query "[0].value" --output tsv | tr -d '"')
	@echo "username=$(DEPLOYMENT_STORAGE);password=$(STORAGE_ACCOUNT_KEY)" > .share-creds

.PHONY: mount-all-shares
mount-all-shares:
	$(MAKE) mount-share SHARE_NAME=data
	$(MAKE) mount-share SHARE_NAME=reference

.PHONY: mount-share
mount-share: get-deployment-vars
ifndef SHARE_NAME
	$(error SHARE_NAME undefined - specify "data" or "reference")
endif
	mkdir ./.$(SHARE_NAME)
	@echo "$(ANSI_GREY)Fetching storage key and mounting $(SHARE_NAME) share locally...$(ANSI_RESET)"
	STORAGE_KEY=$$(az storage account keys list --resource-group $(DEPLOYMENT_RG) --account-name $(DEPLOYMENT_STORAGE) --query "[0].value" --output tsv | tr -d '"') && \
	sudo mount -t cifs //$(DEPLOYMENT_STORAGE).file.core.windows.net/$(SHARE_NAME) ./.$(SHARE_NAME) \
		-o vers=3.1.1,username=$(DEPLOYMENT_STORAGE),password=$$STORAGE_KEY,dir_mode=0777,file_mode=0777
	@echo "$(ANSI_GREEN)Successfully mounted $(ANSI_RESET)./.$(SHARE_NAME)"

.PHONY: unmount-share
unmount-share:
ifndef SHARE_NAME
	$(error SHARE_NAME undefined - specify "data" or "reference")
endif
	@echo "$(ANSI_GREY)Unmounting $(SHARE_NAME) share...$(ANSI_RESET)"
	sudo umount ./.$(SHARE_NAME) && rmdir ./.$(SHARE_NAME)
	@echo "$(ANSI_GREEN)Successfully unmounted $(ANSI_RESET)./.$(SHARE_NAME)"
