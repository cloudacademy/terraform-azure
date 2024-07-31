variable "tenant_id" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type        = string
  default     = "cloudacademydevops-funcdemo"
  description = "azure resource group"
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "azure region"
}
