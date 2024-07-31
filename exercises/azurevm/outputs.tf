#OUTPUTS
#================================

output "vm_public_ip" {
  value = azurerm_public_ip.app.ip_address
}

output "web_app_wait_command" {
  value       = "until curl -s --max-time 5 http://${azurerm_public_ip.app.ip_address} | grep -i world >/dev/null 2>&1; do echo preparing...; sleep 5; done; echo; echo -e 'Ready!!'"
  description = "Test command - tests readiness of the web app"
}
