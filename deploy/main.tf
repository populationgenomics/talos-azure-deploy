resource "azurerm_resource_group" "rg" {
  name     = "${var.deployment_name}-rg"
  location = var.region
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.deployment_name}law"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "env" {
  name                = "env0"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
}

resource "azurerm_container_app_job" "job" {
  name                         = "job0"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.env.id

  replica_timeout_in_seconds = 1800
  replica_retry_limit        = 1
  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      image  = "mcr.microsoft.com/k8se/quickstart-jobs:latest"
      name   = "testcontainerappsjob0"
      cpu    = 0.5
      memory = "1Gi"
    }
  }
}
