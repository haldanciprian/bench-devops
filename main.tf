# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.75.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "azurerm_rg" {
  name = "learning-zone"
}

# resource "azurerm_resource_group" "azurerm_rg" {
#   name     = "learning-zone"
#   location = "France Central"
# }

resource "azurerm_virtual_network" "azurerm_vn" {
  name                = "chaldan-network"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.azurerm_rg.location
  resource_group_name = data.azurerm_resource_group.azurerm_rg.name
  tags = var.tags
}

resource "azurerm_subnet" "azurerm_sn" {
  name                 = "chaldan-sn"
  resource_group_name  = data.azurerm_resource_group.azurerm_rg.name
  virtual_network_name = azurerm_virtual_network.azurerm_vn.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "azurem_pi" {
  name                = "chaldan_public-ip"
  location            = data.azurerm_resource_group.azurerm_rg.location
  resource_group_name = data.azurerm_resource_group.azurerm_rg.name
  allocation_method   = "Dynamic"
  tags = var.tags
}

resource "azurerm_network_security_group" "azurerm_nsg" {
  name                = "chaldan_security_group"
  location            = data.azurerm_resource_group.azurerm_rg.location
  resource_group_name = data.azurerm_resource_group.azurerm_rg.name
  tags = var.tags

  security_rule {
    name                       = "chaldan_dev-rule"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "azurm_nsga" {
  subnet_id                 = azurerm_subnet.azurerm_sn.id
  network_security_group_id = azurerm_network_security_group.azurerm_nsg.id
}

resource "azurerm_network_interface" "azurerm_ni" {
  name                = "chaldan-nic"
  location            = data.azurerm_resource_group.azurerm_rg.location
  resource_group_name = data.azurerm_resource_group.azurerm_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.azurerm_sn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.azurem_pi.id
  }

    tags = var.tags
}

resource "azurerm_linux_virtual_machine" "azurerm_vm" {
  name                = "chaldan-vm"
  resource_group_name = data.azurerm_resource_group.azurerm_rg.name
  location            = data.azurerm_resource_group.azurerm_rg.location
  size                = "Standard_B1ms"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.azurerm_ni.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

   connection {
    type        = "ssh"
    user        = "adminuser"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip_address
  }

  tags = var.tags
}