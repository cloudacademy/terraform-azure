output "ad_vm_public_ip" {
  description = "Windows AD VM Public IP Address"
  value       = module.active-directory-forest.windows_vm_public_ips
}
