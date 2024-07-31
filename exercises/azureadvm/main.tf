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

#AD MODULE
#================================

module "active-directory-forest" {
  source = "github.com/jeremycook123/terraform-azurerm-active-directory-forest-v2"

  resource_group_name  = "cloudacademydevops-enterprise"
  location             = "eastus"
  virtual_network_name = "cloudacademydevops-enterprise"
  subnet_name          = "ad"

  #options: windows2012r2dc, windows2016dc, windows2019dc
  windows_distribution_name = "windows2019dc"

  virtual_machine_name               = "cadevops-ad"
  virtual_machine_size               = "Standard_DS1_v2"
  admin_username                     = var.advm_creds.username
  admin_password                     = var.advm_creds.password
  private_ip_address_allocation_type = "Static"
  private_ip_address                 = ["10.100.1.6"]
  enable_public_ip_address           = true

  active_directory_domain       = "cloudacademydevops.org"
  active_directory_netbios_name = "CLOUDACADEMYDEV"

  nsg_inbound_rules = [
    {
      name                   = "rdp"
      destination_port_range = "3389"
      source_address_prefix  = var.management_ip
      protocol               = "TCP"
    },
    {
      name                   = "dns"
      destination_port_range = "53"
      source_address_prefix  = "*"
      protocol               = "*"
    },
    {
      name                   = "app-vnet"
      destination_port_range = "1024-65535"
      source_address_prefix  = "10.0.0.0/16"
      protocol               = "*"
    },
  ]

  tags = {
    ProjectName  = "cloudacademydevops"
    Env          = "demo"
    Owner        = "jeremy.cook@cloudacademy.com"
    BusinessUnit = "SuccessServices"
    ServiceClass = "Gold"
  }
}
