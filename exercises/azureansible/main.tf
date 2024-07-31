terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
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

provider "tls" {
  # Configuration options
}

provider "random" {
  # Configuration options
}

#RESOURCEGROUP
#================================

resource "azurerm_resource_group" "cloudacademydevops" {
  name     = "${var.resource_group_name}-${terraform.workspace}"
  location = var.location
}

#NETWORK
#================================

resource "azurerm_virtual_network" "main" {
  name                = "main"
  location            = azurerm_resource_group.cloudacademydevops.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  address_space       = ["10.0.0.0/16"]
  dns_servers         = var.dns_servers
}

resource "azurerm_subnet" "public" {
  name                 = "public"
  resource_group_name  = azurerm_resource_group.cloudacademydevops.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "private" {
  name                 = "private"
  resource_group_name  = azurerm_resource_group.cloudacademydevops.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

#peering from cloudacademydevops-enterprise vnet to app-network vnet
resource "azurerm_virtual_network_peering" "peer1to2" {
  name                      = "peer1to2"
  resource_group_name       = "cloudacademydevops-enterprise"
  virtual_network_name      = "cloudacademydevops-enterprise"
  remote_virtual_network_id = azurerm_virtual_network.main.id
}

#peering from app-network vnet to cloudacademydevops-enterprise vnet
resource "azurerm_virtual_network_peering" "peer2to1" {
  name                      = "peer2to1"
  resource_group_name       = azurerm_resource_group.cloudacademydevops.name
  virtual_network_name      = "main"
  remote_virtual_network_id = "/subscriptions/${var.subscription_id}/resourceGroups/cloudacademydevops-enterprise/providers/Microsoft.Network/virtualNetworks/cloudacademydevops-enterprise"

  depends_on = [
    azurerm_virtual_network.main
  ]
}

resource "azurerm_network_interface" "app" {
  count               = 2
  name                = "app-nic-${count.index}"
  location            = azurerm_resource_group.cloudacademydevops.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name

  ip_configuration {
    name                          = "ip_config"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [
    azurerm_subnet.private
  ]
}

#NATGW
#================================

resource "azurerm_public_ip" "natgw" {
  name                = "natgw"
  location            = azurerm_resource_group.cloudacademydevops.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "natgw" {
  name                = "natgw"
  location            = azurerm_resource_group.cloudacademydevops.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "natgw" {
  nat_gateway_id       = azurerm_nat_gateway.natgw.id
  public_ip_address_id = azurerm_public_ip.natgw.id
}

resource "azurerm_subnet_nat_gateway_association" "natgw" {
  subnet_id      = azurerm_subnet.private.id
  nat_gateway_id = azurerm_nat_gateway.natgw.id
}

#SECURITY
#================================

#tfsec:ignore:azure-network-no-public-ingress
resource "azurerm_network_security_group" "app" {
  name                = "app"
  location            = azurerm_resource_group.cloudacademydevops.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name

  security_rule {
    name                       = "allowWinRm"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefix      = var.management_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allowPublicWeb"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allowRDP"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.management_ip
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_network_security_group" "bastion" {
  name                = "bastion"
  location            = azurerm_resource_group.cloudacademydevops.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name

  security_rule {
    name                       = "allowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.management_ip
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}

#LB
#================================

resource "random_string" "fqdn" {
  length  = 6
  special = false
  upper   = false
  numeric = false
}

resource "azurerm_public_ip" "lb" {
  name                = "public-lb-ip"
  location            = azurerm_resource_group.cloudacademydevops.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  allocation_method   = "Static"
  domain_name_label   = random_string.fqdn.result
  sku                 = "Standard"
}

resource "azurerm_availability_set" "app" {
  name                = "app"
  location            = azurerm_resource_group.cloudacademydevops.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
}

resource "azurerm_lb" "lb" {
  name                = "app-lb"
  location            = azurerm_resource_group.cloudacademydevops.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "lb-frontend"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "app_backend_pool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "app-backend-address-pool"
}

resource "azurerm_network_interface_backend_address_pool_association" "app_backend_pool_assoc" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.app[count.index].id
  ip_configuration_name   = "ip_config"
  backend_address_pool_id = azurerm_lb_backend_address_pool.app_backend_pool.id
}

resource "azurerm_lb_probe" "lbprobe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "http-running-probe"
  port            = 80
}

resource "azurerm_lb_rule" "app_lb_rule" {
  name                           = "app-lb-rule"
  loadbalancer_id                = azurerm_lb.lb.id
  probe_id                       = azurerm_lb_probe.lbprobe.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.app_backend_pool.id]
  frontend_ip_configuration_name = "lb-frontend"
  disable_outbound_snat          = true
}

# resource "azurerm_lb_outbound_rule" "outbound" {
#   name                    = "OutboundRule"
#   loadbalancer_id         = azurerm_lb.lb.id
#   protocol                = "All"
#   backend_address_pool_id = azurerm_lb_backend_address_pool.app_backend_pool.id

#   frontend_ip_configuration {
#     name = "lb-frontend"
#   }
# }

#BACKEND COMPUTE
#================================

resource "azurerm_windows_virtual_machine" "app_vms" {
  name                  = "appvm-${count.index}"
  count                 = 2
  location              = var.location
  resource_group_name   = azurerm_resource_group.cloudacademydevops.name
  size                  = "Standard_DS1_v2"
  network_interface_ids = [azurerm_network_interface.app[count.index].id]
  availability_set_id   = azurerm_availability_set.app.id
  computer_name         = "appvm-${count.index}"
  admin_username        = "vmadmin"
  admin_password        = "Password1234!"

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  depends_on = [
    azurerm_network_interface.app
  ]
}

resource "azurerm_virtual_machine_extension" "winrm" {
  name                       = "winrm"
  count                      = 2
  virtual_machine_id         = azurerm_windows_virtual_machine.app_vms[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  settings                   = <<SETTINGS
    {
      "fileUris": ["https://raw.githubusercontent.com/cloudacademy/terraform-ansible/main/scripts/ConfigureRemotingForAnsible.ps1"],
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File ConfigureRemotingForAnsible.ps1"
    }
SETTINGS

  # needs access to the AD DNS server to resolve raw.githubusercontent.com,
  # therefore needs access to route DNS traffic across the peering connection
  depends_on = [
    azurerm_virtual_network_peering.peer1to2,
    azurerm_virtual_network_peering.peer2to1,
    azurerm_windows_virtual_machine.app_vms
  ]
}

#BASTION
#================================

resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "terraform_data" "ssh_private_key" {
  triggers_replace = {
    key = tls_private_key.bastion.private_key_pem
  }

  provisioner "local-exec" {
    command = "echo '${tls_private_key.bastion.private_key_pem}' > ./bastion.pem"
  }
}

resource "azurerm_public_ip" "bastion" {
  name = "bastion-pip"

  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name

  allocation_method = "Static"
  sku               = "Basic"
}

resource "azurerm_network_interface" "bastion" {
  name = "bastion-nic"

  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name

  ip_configuration {
    name                          = "ip_config"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"

    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  depends_on = [
    azurerm_subnet.private
  ]
}

resource "azurerm_linux_virtual_machine" "bastion" {
  name = "bastion"

  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name

  network_interface_ids = [azurerm_network_interface.bastion.id]

  size                            = "Standard_B1s"
  computer_name                   = "bastion"
  admin_username                  = var.jumpbox_creds.username
  admin_password                  = var.jumpbox_creds.password
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.jumpbox_creds.username
    public_key = tls_private_key.bastion.public_key_openssh
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    name                 = "bastion-disk1"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}
