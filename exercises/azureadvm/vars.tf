variable "tenant_id" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "management_ip" {
  type = string
}

variable "advm_creds" {
  sensitive = false
  type = object({
    username = string
    password = string
  })
}
