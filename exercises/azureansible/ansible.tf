#ANSIBLE HOOK
#================================

resource "terraform_data" "ansible" {
  triggers_replace = {
    vm_machine_ids = join(",", azurerm_windows_virtual_machine.app_vms[*].virtual_machine_id)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = "${path.module}/ansible"
    command     = <<EOT
      sleep 120 #time to allow VMs to come online and stabilize
      mkdir -p ./logs

      sed 's/HOST_IPS/${join("\\n", azurerm_network_interface.app[*].private_ip_address)}/g' ./templates/hosts > hosts

      #required for macos only
      export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

      #start SOCKS5 port forwarding
      chmod 600 ../bastion.pem
      ssh -fnNM \
       -S /tmp/.ssh-azure-terraform-socks \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -i ../bastion.pem \
       -D 12345 \
       ${var.jumpbox_creds.username}@${azurerm_public_ip.bastion.ip_address}

      #ANSIBLE
      #use -vvv for extra verbosity
      ansible-playbook -v -i hosts ./playbooks/master.yml || true

      #kill SOCKS5 port forwarding
      ssh -S /tmp/.ssh-azure-terraform-socks -O exit ${azurerm_public_ip.bastion.ip_address} || true

      echo finished!
    EOT
  }

  depends_on = [
    azurerm_virtual_machine_extension.winrm,
    azurerm_public_ip.bastion,
    azurerm_subnet_nat_gateway_association.natgw
  ]
}
