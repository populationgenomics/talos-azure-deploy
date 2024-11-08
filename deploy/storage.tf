resource "azurerm_storage_account" "sa" {
  name                     = "${var.deployment_name}sa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Premium"
  account_kind             = "FileStorage"
  account_replication_type = "LRS"
  # Must allow shared key access - MSI not supported
  local_user_enabled       = false
}

resource "azurerm_storage_share" "reference" {
  name                 = "reference"
  storage_account_name = azurerm_storage_account.sa.name
  enabled_protocol     = "NFS"
  quota                = 1000
}

resource "azurerm_container_app_environment_storage" "reference_storage" {
  name                         = "reference-storage"
  container_app_environment_id = azurerm_container_app_environment.env.id
  account_name                 = azurerm_storage_account.sa.name
  share_name                   = azurerm_storage_share.reference.name
  access_key                   = azurerm_storage_account.sa.primary_access_key
  access_mode                  = "ReadOnly"
}
