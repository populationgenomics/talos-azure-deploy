resource "azurerm_resource_group" "rg" {
  name     = "${var.deployment_name}-rg"
  location = var.region
  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.deployment_name}law"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "env" {
  name                       = "${var.deployment_name}env"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    maximum_count         = 0
    minimum_count         = 0
  }

  workload_profile {
    name                  = "Dedicated_D8"
    workload_profile_type = "D8"
    maximum_count         = 4
    minimum_count         = 0
  }
}

resource "azurerm_user_assigned_identity" "umi" {
  name                = "${var.deployment_name}-umi"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region
}

resource "azurerm_container_app_job" "job" {
  name                         = "job-runner"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.env.id

  workload_profile_name      = "Dedicated_D8"
  # One day
  replica_timeout_in_seconds = 86400
  replica_retry_limit        = 1
  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.umi.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.umi.id
  }

  template {
    volume {
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.reference_storage.name
      name         = "reference-volume"
    }
    volume {
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.data_storage.name
      name         = "data-volume"
    }
    container {
      # Bootstrap issue: when first creating the infrastructure, the private images aren't yet available.
      # Define the job with a placeholder image here, then override it with the private image at job run time.
      # e.g. image  = "${azurerm_container_registry.acr.login_server}/talos-run:latest"
      image  = "mcr.microsoft.com/k8se/quickstart-jobs:latest"
      name   = "job-runner"
      cpu    = 2.0
      memory = "4.0Gi"
      volume_mounts {
        name = "reference-volume"
        path = "/reference"
      }
      volume_mounts {
        name = "data-volume"
        path = "/data"
      }
    }
  }

  depends_on = [azurerm_role_assignment.acr_pull]
}

resource "azurerm_container_registry" "acr" {
  name                   = "${var.deployment_name}acr"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  sku                    = "Premium"
  anonymous_pull_enabled = false
  admin_enabled          = false
}

# TODO: auth model for makefile build/push?
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  principal_id         = azurerm_user_assigned_identity.umi.principal_id
  role_definition_name = "AcrPull"
}
