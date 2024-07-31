output "load_balancer_public_ip" {
  value       = azurerm_public_ip.loadbalancer.ip_address
  description = "value of the load balancer public ip"
}

output "load_balancer_fqdn" {
  value       = azurerm_public_ip.loadbalancer.fqdn
  description = "value of the load balancer fqdn"
}

output "jumpbox_public_ip" {
  value       = azurerm_public_ip.bastion.ip_address
  description = "value of the jumpbox public ip"
}

output "web_app_wait_command" {
  value       = "until curl -s --max-time 5 http://${azurerm_public_ip.loadbalancer.fqdn} | grep -i vote >/dev/null 2>&1; do echo preparing...; sleep 5; done; echo; echo -e 'Ready!!'"
  description = "Test command - tests readiness of the web app"
}
