terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  skip_provider_registration = true
  tenant_id                  = var.tenant_id
  subscription_id            = var.subscription_id
}

resource "azurerm_resource_group" "cloudacademydevops_rg" {
  name     = "${var.resource_group_name}-${terraform.workspace}"
  location = var.location
}

#NETWORK
#================================

resource "azurerm_virtual_network" "main" {
  name                = "app-network"
  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops_rg.name

  address_space = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "internal" {
  name                = "internal"
  resource_group_name = azurerm_resource_group.cloudacademydevops_rg.name

  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

#tfsec:ignore:azure-network-no-public-ingress
#tfsec:ignore:azure-network-ssh-blocked-from-internet
resource "azurerm_network_security_group" "app_nsg" {
  name                = "app-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops_rg.name

  security_rule {
    name                       = "allowPublicWeb"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allowSSH"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "app" {
  name                = "app-vm-ip1"
  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops_rg.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "app" {
  name                = "app-nic1"
  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops_rg.name

  ip_configuration {
    name                          = "ip_config"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"

    public_ip_address_id = azurerm_public_ip.app.id
  }

  depends_on = [
    azurerm_subnet.internal
  ]
}

resource "azurerm_subnet_network_security_group_association" "app_nsg_assoc" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

#VM
#================================

#tfsec:ignore:azure-compute-disable-password-authentication
resource "azurerm_linux_virtual_machine" "app" {
  name                = "app-linuxvm1"
  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops_rg.name

  network_interface_ids = [azurerm_network_interface.app.id]

  size                            = "Standard_B1s"
  computer_name                   = "terraformide"
  admin_username                  = "superadmin"
  admin_password                  = "2rC%G1A4"
  disable_password_authentication = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    name                 = "app-disk1"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  custom_data = base64encode(<<EOF
#! /bin/bash
apt-get -y update
apt-get -y install nginx

cd /var/www/html
rm *.html
git clone https://github.com/cloudacademy/webgl-globe/ .
cp -a src/* .
rm -rf {.git,*.md,src,conf.d,docs,Dockerfile,index.nginx-debian.html}

systemctl restart nginx
systemctl status nginx
echo fin v1.00!
EOF
  )

  tags = {
    org       = "CloudAcademy"
    workspace = terraform.workspace
  }
}
