terraform {
  required_version = ">= 1.10.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.3"
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

#RESOURCEGROUP
#================================

resource "azurerm_resource_group" "cloudacademydevops" {
  name     = "${var.resource_group_name}-${terraform.workspace}"
  location = var.location
}

#STORAGE ACCOUNT
#================================

#tfsec:ignore:azure-storage-use-secure-tls-policy
resource "azurerm_storage_account" "sa" {
  name                        = "cloudacademydevopsfuncs"
  resource_group_name         = azurerm_resource_group.cloudacademydevops.name
  location                    = azurerm_resource_group.cloudacademydevops.location
  account_tier                = "Standard"
  account_replication_type    = "LRS"
  account_kind                = "StorageV2"
  https_traffic_only_enabled  = true
}

#SERVICE PLAN
#================================

resource "azurerm_service_plan" "asp" {
  name                = "cloudacademydevops-asp"
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  location            = azurerm_resource_group.cloudacademydevops.location
  os_type             = "Linux"
  sku_name            = "B1"
}

#APP INSIGHTS
#================================

resource "azurerm_application_insights" "cloudacademy" {
  name                = "cloudacademydevops"
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  location            = azurerm_resource_group.cloudacademydevops.location
  application_type    = "other"
}

#FUNCTION APP
#================================

resource "azurerm_linux_function_app" "cloudacademydevops" {
  name                = "cloudacademydevops-func-app"
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  location            = azurerm_resource_group.cloudacademydevops.location

  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  service_plan_id            = azurerm_service_plan.asp.id

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME       = "python"
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.cloudacademy.instrumentation_key
  }

  site_config {
    application_stack {
      python_version = "3.9"
    }
  }
}

# #FUNCTION1
# #================================

# resource "azurerm_function_app_function" "func1" {
#   name            = "cloudacademy"
#   function_app_id = azurerm_linux_function_app.cloudacademydevops.id
#   language        = "Python"

#   #deploy function
#   file {
#     name    = "__init__.py"
#     content = file("${path.module}/cloudacademydevops-func-app/cloudacademy-fn1/__init__.py")
#   }

#   config_json = jsonencode({
#     "scriptFile" : "__init__.py",
#     "bindings" = [
#       {
#         "authLevel" = "anonymous"
#         "direction" = "in"
#         "methods" = [
#           "get"
#         ]
#         "name" = "req"
#         "type" = "httpTrigger"
#       },
#       {
#         "direction" = "out"
#         "name"      = "$return"
#         "type"      = "http"
#       },
#     ]
#   })
#   lifecycle {
#     ignore_changes = [
#       file
#     ]
#   }
# }

#PUBLISH FUNCTIONS
#================================

locals {
  app_name  = yamldecode(file("./config.yaml"))["name"]
  version   = yamldecode(file("./config.yaml"))["version"]
  functions = yamldecode(file("./config.yaml"))["functions"]
}

resource "terraform_data" "publish_fns" {
  triggers_replace = {
    functions = "${local.version}_${join("+", [for value in local.functions : value["name"]])}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = "./cloudacademydevops-func-app"
    command     = <<-EOF
    ls -la
    # test readiness of the function app
    until func azure functionapp list-functions ${local.app_name} --subscription ${var.subscription_id}; do echo preparing...; sleep 5; done; printf '\nReady for fn publishing!!\n'
    func azure functionapp publish ${local.app_name} --python --subscription ${var.subscription_id}
    printf '\npublished functions successfully!!\n'
    EOF
  }

  depends_on = [
    azurerm_linux_function_app.cloudacademydevops
  ]
}
