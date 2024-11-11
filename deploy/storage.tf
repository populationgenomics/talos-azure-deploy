resource "azurerm_storage_account" "sa" {
  name                     = "${var.deployment_name}sa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Premium"
  account_kind             = "FileStorage"
  account_replication_type = "LRS"
  # Container App NFS shares require secure transfer disabled and shared key access.
  https_traffic_only_enabled = false
  # Can't use azurerm_storage_share to create shares because once the
  # network rules are set up Terraform no longer has access to them.
  provisioner "local-exec" {
    command = <<EOT
        az storage share-rm create \
            --name reference \
            --resource-group ${azurerm_resource_group.rg.name} \
            --storage-account ${self.name} \
            --enabled-protocols NFS \
            --quota 500
        az storage share-rm create \
            --name data \
            --resource-group ${azurerm_resource_group.rg.name} \
            --storage-account ${self.name} \
            --enabled-protocols NFS \
            --quota 500
    EOT
  }
}

resource "azurerm_storage_account_network_rules" "sa_rules" {
  storage_account_id = azurerm_storage_account.sa.id
  # Deny = "Enabled from selected virtual networks and IP addresses"
  default_action             = "Deny"
  virtual_network_subnet_ids = [azurerm_subnet.ca_subnet.id]
  ip_rules                   = ["131.107.0.0/16"]
}

resource "azurerm_container_app_environment_storage" "reference_storage" {
  name                         = "reference-storage"
  container_app_environment_id = azurerm_container_app_environment.env.id
  account_name                 = azurerm_storage_account.sa.name
  access_key                   = azurerm_storage_account.sa.primary_access_key
  access_mode                  = "ReadOnly"
  share_name                   = "reference"
}

resource "azurerm_container_app_environment_storage" "data_storage" {
  name                         = "data-storage"
  container_app_environment_id = azurerm_container_app_environment.env.id
  account_name                 = azurerm_storage_account.sa.name
  access_key                   = azurerm_storage_account.sa.primary_access_key
  access_mode                  = "ReadWrite"
  share_name                   = "data"
}

}
