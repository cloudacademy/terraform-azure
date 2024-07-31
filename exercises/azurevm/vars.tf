variable "tenant_id" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type    = string
  default = "cloudacademydevops-vm"
}

variable "location" {
  type    = string
  default = "eastus"
}
