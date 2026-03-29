output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.this.name
}

output "public_ip_address" {
  value = azurerm_public_ip.this.ip_address
}

output "ssh_command" {
  value = "ssh -i ${var.private_key_output_path} ${var.admin_username}@${azurerm_public_ip.this.ip_address}"
}

output "app_url" {
  value = var.open_app_port ? "http://${azurerm_public_ip.this.ip_address}:${var.app_port}" : null
}

output "auto_shutdown_note" {
  value = "Auto-shutdown runs daily at ${var.auto_shutdown_time_utc} ${var.auto_shutdown_timezone}. 1600 UTC = 12:00 AM Malaysia time."
}
