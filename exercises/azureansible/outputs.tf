output "load_balancer_fqdn" {
  value = azurerm_public_ip.lb.fqdn
}

output "load_balancer_ip" {
  value = azurerm_public_ip.lb.ip_address
}

output "bastion_public_ip" {
  value = azurerm_public_ip.bastion.ip_address
}

output "natgw_public_ip" {
  value = azurerm_public_ip.natgw.ip_address
}

output "app_vms_private_ips" {
  value = azurerm_network_interface.app[*].private_ip_address
}
