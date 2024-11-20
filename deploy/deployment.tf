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
}

variable "region" {
  description = "Azure region in which to deploy resources (e.g. 'eastus')."
  type        = string
  nullable    = false
}

variable "tenant_id" {
  description = "Tenant in which to deploy resources."
  type        = string
  nullable    = false
}

variable "subscription_id" {
  description = "Subscription in which to deploy resources."
  type        = string
  nullable    = false
}
