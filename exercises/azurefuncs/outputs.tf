output "cloudacademydevops_function_app_hostname" {
  value       = azurerm_linux_function_app.cloudacademydevops.default_hostname
  description = "Function App Hostname"
}

output "cloudacademydevops_function_app_name" {
  value       = azurerm_linux_function_app.cloudacademydevops.name
  description = "Function App Name"
}

output "cloudacademydevops_function1_url" {
  value       = "https://${azurerm_linux_function_app.cloudacademydevops.name}.azurewebsites.net/api/fn-cloudacademy"
  description = "CloudAcademy Function 1 - Basic"
}

output "cloudacademydevops_function2_url" {
  value       = "https://${azurerm_linux_function_app.cloudacademydevops.name}.azurewebsites.net/api/fn-bitcoin"
  description = "CloudAcademy Function 2 - Bitcoin Price"
}

output "cloudacademydevops_function3_url" {
  value       = "https://${azurerm_linux_function_app.cloudacademydevops.name}.azurewebsites.net/api/fn-pi"
  description = "CloudAcademy Function 3 - Pi Number Generator"
}

output "cloudacademydevops_function4_url" {
  value       = "https://${azurerm_linux_function_app.cloudacademydevops.name}.azurewebsites.net/api/fn-pi-random-error"
  description = "CloudAcademy Function 4 - Pi Number Generator"
}

output "wait_command" {
  value       = "until curl --max-time 5 -is https://${azurerm_linux_function_app.cloudacademydevops.name}.azurewebsites.net/api/fn-cloudacademy | grep -q '200 OK'; do echo preparing...; sleep 5; done; printf '\nReady!!\n'"
  description = "Test command - tests readiness of the function app"
}
