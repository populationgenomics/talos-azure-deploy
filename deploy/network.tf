resource "azurerm_virtual_network" "default" {
  name                = "default"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/8"]
}

# Subnet for Container App.
resource "azurerm_subnet" "ca_subnet" {
  name                 = "ca-subnet"
  address_prefixes     = ["10.240.0.0/16"]
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name

  delegation {
    name = "ContainerApp"
    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }

  service_endpoints = ["Microsoft.Storage"]
}
