resource "azurerm_storage_account" "sa" {
  name                     = "${var.deployment_name}sa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Premium"
  account_kind             = "FileStorage"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "reference" {
  name                 = "reference"
  storage_account_name = azurerm_storage_account.sa.name
  enabled_protocol     = "SMB"
  quota                = 500
}

resource "azurerm_storage_share" "data" {
  name                 = "data"
  storage_account_name = azurerm_storage_account.sa.name
  enabled_protocol     = "SMB"
  quota                = 500
}

resource "azurerm_storage_share_directory" "example_dataset" {
  name             = "example-dataset"
  storage_share_id = azurerm_storage_share.data.id
}
resource "azurerm_storage_share_file" "example_files" {
  for_each         = toset(["pedigree.ped", "phenopackets.json", "small_variants.vcf.bgz", "small_variants.vcf.bgz.tbi"])
  storage_share_id = azurerm_storage_share.data.id
  source           = "example-dataset/${each.value}"
  path             = azurerm_storage_share_directory.example_dataset.name
  name             = each.value
}

resource "azurerm_container_app_environment_storage" "reference_storage" {
  name                         = "reference-storage"
  container_app_environment_id = azurerm_container_app_environment.env.id
  account_name                 = azurerm_storage_account.sa.name
  access_key                   = azurerm_storage_account.sa.primary_access_key
  share_name                   = azurerm_storage_share.reference.name
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app_environment_storage" "data_storage" {
  name                         = "data-storage"
  container_app_environment_id = azurerm_container_app_environment.env.id
  account_name                 = azurerm_storage_account.sa.name
  access_key                   = azurerm_storage_account.sa.primary_access_key
  share_name                   = azurerm_storage_share.data.name
  access_mode                  = "ReadWrite"
}

