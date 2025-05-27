terraform {
  required_version = ">= 1.10.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.3"
    }
    cloudinit = {
      source = "hashicorp/cloudinit"
      version = "~> 2.3"
    }    
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}


provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}

provider "cloudinit" {
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

resource "azurerm_virtual_network" "prod" {
  name                = "cloudacademy-voteapp-prod"
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name

  tags = {
    org = "cloudacademy"
    app = "voteapp"
  }
}

resource "azurerm_subnet" "main" {
  name                 = "main"
  resource_group_name  = azurerm_resource_group.cloudacademydevops.name
  virtual_network_name = azurerm_virtual_network.prod.name
  
  address_prefixes = [
    cidrsubnet(
      var.vnet_address_space,
      var.subnet_prefix_length - tonumber(regex(".*\\/(\\d+)", var.vnet_address_space)[0]),
      0
    )
  ]
}

#================================

resource "random_string" "fqdn" {
  length  = 6
  special = false
  upper   = false
  numeric = false
}

resource "azurerm_network_security_group" "voteapp" {
  name                = "voteapp"
  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name

  dynamic "security_rule" {
    for_each = var.voteapp_nsg_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }

  tags = {
    org = "cloudacademy"
    app = "voteapp"
  }
}

resource "azurerm_subnet_network_security_group_association" "voteapp" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.voteapp.id
}

#LOADBALANCER
#================================

resource "azurerm_public_ip" "loadbalancer" {
  name                = "loadbalancer"
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  location            = var.location
  allocation_method   = "Static"
  domain_name_label   = random_string.fqdn.result
  sku                 = "Standard"
  zones               = [1, 2, 3]

  tags = {
    org = "cloudacademy"
    app = "voteapp"
  }
}

resource "azurerm_lb" "web" {
  name                = "web"
  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.loadbalancer.id
  }

  tags = {
    org = "cloudacademy"
    app = "voteapp"
  }
}

resource "azurerm_lb_backend_address_pool" "frontend" {
  name            = "frontend"
  loadbalancer_id = azurerm_lb.web.id
}

resource "azurerm_lb_backend_address_pool" "api" {
  name            = "api"
  loadbalancer_id = azurerm_lb.web.id
}


resource "azurerm_lb_probe" "frontend" {
  name            = "frontend"
  loadbalancer_id = azurerm_lb.web.id
  port            = 80
}

resource "azurerm_lb_probe" "api" {
  name            = "api"
  loadbalancer_id = azurerm_lb.web.id
  port            = 8080
}

resource "azurerm_lb_rule" "frontend" {
  loadbalancer_id                = azurerm_lb.web.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.frontend.id]
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.frontend.id
}

resource "azurerm_lb_rule" "api" {
  loadbalancer_id                = azurerm_lb.web.id
  name                           = "api"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.api.id]
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.api.id
}

#FRONTEND
#================================

data "cloudinit_config" "frontend" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
    #! /bin/bash
    apt-get -y update
    apt-get -y install nginx jq

    LB_FQDN=${azurerm_public_ip.loadbalancer.fqdn}

    echo "deployment starting..."
    echo ===========================
    echo FRONTEND - download latest release and install...
    mkdir -p ./voteapp-frontend-react-2023
    cd ./voteapp-frontend-react-2023

    curl -sL https://api.github.com/repos/cloudacademy/voteapp-frontend-react-2023/releases/latest | jq -r '.assets[0].browser_download_url' | xargs curl -OL
    tar -xvf *.tar.gz
    rm -rf /var/www/html
    cp -R build /var/www/html
    cat > /var/www/html/env-config.js << EOFF
    window._env_ = {REACT_APP_APIHOSTPORT: "$LB_FQDN:8080"}
    EOFF

    systemctl restart nginx
    systemctl status nginx

    echo "deployment finished!"
    EOF
  }
}

resource "azurerm_linux_virtual_machine_scale_set" "frontend" {
  name                = "frontend"
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  location            = azurerm_resource_group.cloudacademydevops.location
  sku                 = "Standard_DS1_v2"
  instances           = 1
  zones               = [1, 2, 3]

  admin_username                  = "cloudacademy"
  admin_password                  = "E3I8w$qL"
  disable_password_authentication = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "example"
    primary = true

    ip_configuration {
      name                                   = "IPConfiguration"
      subnet_id                              = azurerm_subnet.main.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.frontend.id]
      primary                                = true
    }
  }

  custom_data = data.cloudinit_config.frontend.rendered

  tags = {
    org = "cloudacademy"
    app = "voteapp"
  }

  depends_on = [
    azurerm_public_ip.loadbalancer
  ]
}

resource "azurerm_monitor_autoscale_setting" "web" {
  name                = "web"
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  location            = azurerm_resource_group.cloudacademydevops.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.frontend.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 4
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.frontend.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 30
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        dimensions {
          name     = "AppName"
          operator = "Equals"
          values   = ["App1"]
        }
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.frontend.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }

  tags = {
    org = "cloudacademy"
    app = "voteapp"
  }
}

#API
#================================

data "cloudinit_config" "api" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
    #! /bin/bash
    apt-get -y update
    apt-get -y install jq

    echo "deployment starting..."
    echo ===========================
    echo API - download latest release, install, and start...
    mkdir -p ./voteapp-api-go
    cd ./voteapp-api-go
    curl -sL https://api.github.com/repos/cloudacademy/voteapp-api-go/releases/latest | jq -r '.assets[] | select(.name | contains("linux-amd64")) | .browser_download_url' | xargs curl -OL
    tar -xvf *.tar.gz
    #start the API up...
    MONGO_CONN_STR="${var.mongo_db_config.connection_string}" MONGO_USERNAME="${var.mongo_db_config.username}" MONGO_PASSWORD="${var.mongo_db_config.password}" ./api &

    echo "deployment finished!"
    EOF
  }
}

resource "azurerm_linux_virtual_machine_scale_set" "api" {
  name                = "api"
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  location            = azurerm_resource_group.cloudacademydevops.location
  sku                 = "Standard_DS1_v2"
  instances           = 1
  zones               = [1, 2, 3]

  admin_username                  = "cloudacademy"
  admin_password                  = "E3I8w$qL"
  disable_password_authentication = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "example"
    primary = true

    ip_configuration {
      name                                   = "IPConfiguration"
      subnet_id                              = azurerm_subnet.main.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.api.id]
      primary                                = true
    }
  }

  custom_data = data.cloudinit_config.api.rendered

  tags = {
    org = "cloudacademy"
    app = "voteapp"
  }
}

#BASTION
#================================

resource "azurerm_public_ip" "bastion" {
  name                = "bastion"
  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  allocation_method   = "Static"
  domain_name_label   = "${random_string.fqdn.result}-bastion"

  tags = {
    org = "cloudacademy"
    app = "voteapp"
  }
}

resource "azurerm_network_interface" "bastion" {
  name                = "bastion"
  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name

  ip_configuration {
    name                          = "IPConfiguration"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion.id
  }

  tags = {
    org = "cloudacademy"
    app = "voteapp"
  }
}

resource "azurerm_virtual_machine" "bastion" {
  name                  = "bastion"
  location              = var.location
  resource_group_name   = azurerm_resource_group.cloudacademydevops.name
  network_interface_ids = [azurerm_network_interface.bastion.id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "jumpbox-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "jumpbox"
    admin_username = "cloudacademy"
    admin_password = "E3I8w$qL"
  }

  #tfsec:ignore:azure-compute-disable-password-authentication
  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    org = "cloudacademy"
    app = "voteapp"
  }
}
