# This configuration file defines the azurerm backend/provider blocks and the variables used for deploying
# with `deploy-init.sh`. The backend block is empty as configuration at runtime is provided by the script.
terraform {
  required_version = ">=1.9.5"
  backend "azurerm" {
    tenant_id            = "72f988bf-86f1-41af-91ab-2d7cd011db47"
    subscription_id      = "a0e0e744-06b2-4fd3-9230-ebf8ef1ac4c8"
    storage_account_name = "bmcdeployments"
    container_name       = "talosmsr0"
    use_azuread_auth     = true
    key                  = "deploy.tfstate"
  }
  # Include the following azurerm block in required_providers
  # along with any other providers you need.
  # required_providers {
  #   azurerm = {
  #     source  = "hashicorp/azurerm"
  #     version = "~>4.1.0"
  #   }
  # }
}

provider "azurerm" {
  features {}
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  # Note this assumes that necessary resource providers have already been registered in the target subscription.
  # If not, the errors can be misleading (e.g. "API version 2019-XX-XX was not found for Microsoft.Network")
  resource_provider_registrations = "none"
  # Use the interactive login to authenticate with Azure.
  use_cli = true
}

# These are the variables `deploy-init.sh` automatically provides based on the deployment environment.
variable "deployment_name" {
  description = "Master deployment name, suitable as a prefix to derive various unique resource names."
  type        = string
  nullable    = false
  validation {
    condition = alltrue([
      can(regex("^[0-9a-z]+$", var.deployment_name)),
      length(var.deployment_name) >= 8,
      length(var.deployment_name) <= 16
    ])
    error_message = "Variable deployment_name must be 8-16 characters lowercase alphanumeric."
  }
  default = "talosmsr0"
}
variable "region" {
  description = "Azure region in which to deploy resources (e.g. 'eastus')."
  type        = string
  nullable    = false
  default     = "eastus2"
}
variable "tenant_id" {
  description = "Tenant in which to deploy resources."
  type        = string
  nullable    = false
  default     = "72f988bf-86f1-41af-91ab-2d7cd011db47"
}
variable "subscription_id" {
  description = "Subscription in which to deploy resources."
  type        = string
  nullable    = false
  default     = "a0e0e744-06b2-4fd3-9230-ebf8ef1ac4c8"
}
