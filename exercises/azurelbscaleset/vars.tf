variable "tenant_id" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type        = string
  description = "azure resource group"
  default     = "cloudacademydevops-lbscaleset"
}

variable "location" {
  type        = string
  description = "azure region"
}

variable "vnet_address_space" {
  description = "Base address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_prefix_length" {
  description = "Prefix length for the subnet"
  type        = number
  default     = 24
}

variable "voteapp_nsg_rules" {
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
  description = "nsg ruleset for voteapp"
}

variable "mongo_db_config" {
  sensitive = true
  type = object({
    connection_string = string
    username          = string
    password          = string
  })
  description = "mongodb connection details"
}
