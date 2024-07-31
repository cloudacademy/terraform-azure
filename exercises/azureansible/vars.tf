variable "tenant_id" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "management_ip" {
  type = string
}

variable "dns_servers" {
  type = list(string)
}

variable "jumpbox_creds" {
  type = object({
    username = string
    password = string
  })
  description = "jumpbox host credentials"
}
