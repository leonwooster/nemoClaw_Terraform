variable "subscription_id" {
  description = "Azure subscription ID. Leave blank to use Azure CLI / environment auth if your provider setup supports it."
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "Azure resource group name."
  type        = string
  default     = "nemoclaw-rg"
}

variable "location" {
  description = "Azure region. southeastasia is suitable for Malaysia."
  type        = string
  default     = "southeastasia"
}

variable "name_prefix" {
  description = "Prefix used for Azure resource names."
  type        = string
  default     = "nemoclaw"
}

variable "vm_name" {
  description = "Name of the Linux VM."
  type        = string
  default     = "nemoclaw-vm"
}

variable "computer_name" {
  description = "Hostname inside the VM."
  type        = string
  default     = "nemoclawvm"
}

variable "admin_username" {
  description = "Admin username for SSH."
  type        = string
  default     = "azureuser"
}

variable "vm_size" {
  description = "Cost-optimized burstable VM size. Standard_B2s is a good starting point for RM100-RM200/month range."
  type        = string
  default     = "Standard_B1ms"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB."
  type        = number
  default     = 30
}

variable "os_disk_storage_account_type" {
  description = "OS disk storage account type."
  type        = string
  default     = "StandardSSD_LRS"
}

variable "image_publisher" {
  description = "Azure Marketplace image publisher."
  type        = string
  default     = "Canonical"
}

variable "image_offer" {
  description = "Azure Marketplace image offer."
  type        = string
  default     = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  description = "Azure Marketplace image SKU."
  type        = string
  default     = "22_04-lts-gen2"
}

variable "image_version" {
  description = "Azure Marketplace image version."
  type        = string
  default     = "latest"
}

variable "vnet_cidr" {
  description = "Virtual network CIDR block."
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_cidr" {
  description = "Subnet CIDR block."
  type        = string
  default     = "10.10.1.0/24"
}

variable "ssh_source_cidr" {
  description = "CIDR allowed to SSH to the VM. Replace with your public IP CIDR for better security."
  type        = string
  default     = "0.0.0.0/0"
}

variable "open_app_port" {
  description = "Whether to open the app port publicly."
  type        = bool
  default     = true
}

variable "app_port" {
  description = "Application port to open, for example 3000."
  type        = number
  default     = 3000
}

variable "app_source_cidr" {
  description = "CIDR allowed to access the app port. Replace with a trusted source range if possible."
  type        = string
  default     = "0.0.0.0/0"
}

variable "timezone" {
  description = "Timezone inside the VM."
  type        = string
  default     = "Asia/Kuala_Lumpur"
}

variable "install_nemoclaw" {
  description = "Whether cloud-init should attempt the NVIDIA NemoClaw installer."
  type        = bool
  default     = false
}

variable "auto_shutdown_time_utc" {
  description = "Daily auto-shutdown time in 24h HHMM format. For 12:00 AM Malaysia time, use 1600 UTC."
  type        = string
  default     = "1600"
}

variable "auto_shutdown_timezone" {
  description = "Timezone used by Azure auto-shutdown schedule. UTC keeps the conversion explicit."
  type        = string
  default     = "UTC"
}

variable "write_private_key_to_disk" {
  description = "Whether Terraform should write the generated SSH private key to a local file."
  type        = bool
  default     = true
}

variable "private_key_output_path" {
  description = "Where Terraform writes the generated SSH private key locally."
  type        = string
  default     = "./id_rsa_nemoclaw"
}

variable "tags" {
  description = "Tags applied to Azure resources."
  type        = map(string)
  default = {
    project     = "nemoclaw"
    environment = "dev"
    owner       = "leon"
    costcenter  = "experimentation"
  }
}
