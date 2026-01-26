packer {
  required_plugins {
    hyperv = {
      version = ">= 1.1.5"
      source  = "github.com/hashicorp/hyperv"
    }
  }
}

variable "primary_iso" {
  type        = string
  description = "Path to primary bootable .iso file"
  default     = "none"
}

variable "secondary_iso" {
  type        = string
  description = "Path to secondary provisioning .iso file, with autounattend.xml, bootstrap scripts, configs & install files"
  default     = "none"
}

variable "output_base_path" {
  type        = string
  description = "Base output folder path where artifacts are stored"
  default     = "../../output"
}

variable "hyperv_switch_name" {
  type        = string
  description = "Hyper-V virtual switch name to attach the VM to"
  default     = "Default Switch"
}

variable "hyperv_generation" {
  type        = number
  description = "Hyper-V VM generation (2 for UEFI)"
  default     = 2
}

variable "vm_cpus" {
  type        = number
  description = "Number of vCPUs assigned to the VM"
  default     = 4
}

variable "vm_memory" {
  type        = number
  description = "VM memory in MB"
  default     = 8192
}

# May be not necessary, cuz packer connects to sshd with private key, no user name is specified.
variable "admin_username" {
  type        = string
  description = "Account used by communicator" 
  default     = "packer"
}

variable "ssh_private_key_file" {
  type        = string
  description = "Path to private ssh key, should be in current user home folder in .ssh subfolder"
  default     = "none"
}

variable "ssh_timeout" {
  type        = string
  description = "Timeout for SSH communicator"
  default     = "4h"
}

variable "shutdown_timeout" {
  type        = string
  description = "Timeout for shutdown after sysprep"
  default     = "30m"
}

variable "time_zone" {
  type        = string
  description = "Windows time zone name (Set-TimeZone -Name). Leave empty to skip changing timezone."
  default     = "Central Standard Time"
}

variable "iso_checksum" {
  type        = string
  description = "SHA256 checksum of the primary ISO (format: sha256:<hash>)"
  default     = "none"
}

variable "vm_name" {
  type        = string
  description = "Template VM name; also used as subfolder name under packer output path."
  default     = "none"
}

variable "enable_secure_boot" {
  type        = bool
  description = "Enable Secure Boot for Gen 2 VMs"
  default     = true
}

variable "temp_path" {
  type        = string
  description = "Temporary directory for Packer build (Uses local overwrite)"
  default     = ""
}

variable "enable_tpm" {
  type        = bool
  description = "Enable virtual TPM for the VM (required for Windows 11 Enterprise)"
  default     = false
}

variable "enable_virtualization_extensions" {
  type        = bool
  description = "Enable nested virtualization extensions (required for Windows Server Core with Hyper-V)"
  default     = false
}

variable "enable_mac_spoofing" {
  type        = bool
  description = "Enable MAC spoofing for nested virtualization"
  default     = false
}

variable "admin_deploy_username" {
  type        = string
  description = "Username for admin deployment account"
  default     = "admin-deploy"
}

variable "admin_deploy_password" {
  type        = string
  description = "Password for admin deployment account"
  sensitive   = true
  default     = ""
}

source "hyperv-iso" "windows_server" {
  vm_name = var.vm_name

  # Media
  iso_url              = var.primary_iso
  iso_checksum         = var.iso_checksum
  secondary_iso_images = [var.secondary_iso]

  # So far, boot_command is not working for me, but it may work better for someone else +
  #  don't interfere with my "no prompt" method
  boot_wait = "1s"
  boot_command = ["a<enter><wait>a<enter><wait>a<enter><wait>a<enter>"]
  # boot_command = ["<tab><wait5s><enter><tab><enter><space><wait5s>"]
  # boot_command = ["<wait10s>a<space>a<tab>a<enter>a<space>"]

  first_boot_device = "DVD"

  # Communicator
  communicator          = "ssh"
  ssh_username          = var.admin_username
  ssh_private_key_file  = var.ssh_private_key_file
  ssh_agent_auth        = false
  ssh_timeout           = var.ssh_timeout

  # VM configuration
  cpus        = var.vm_cpus
  memory      = var.vm_memory
  disk_size   = 40960
  generation  = var.hyperv_generation
  switch_name = var.hyperv_switch_name

  # Secure Boot (UEFI Gen2)
  enable_secure_boot           = var.enable_secure_boot
  secure_boot_template         = "MicrosoftWindows"
  enable_tpm                   = var.enable_tpm
  enable_virtualization_extensions = var.enable_virtualization_extensions
  enable_mac_spoofing          = var.enable_mac_spoofing

  # Temporary directory for build
  temp_path = var.temp_path != "" ? var.temp_path : null

  # Output
  output_directory = "${var.output_base_path}/${var.vm_name}"

  # Generalize
  shutdown_command = "C:\\Windows\\System32\\Sysprep\\sysprep.exe /generalize /oobe /shutdown /unattend:C:\\Windows\\System32\\Sysprep\\unattend.xml"
  shutdown_timeout = var.shutdown_timeout
}

build {
  sources = ["source.hyperv-iso.windows_server"]

  provisioner "powershell" {
    inline = [
      "if (\"${var.time_zone}\" -ne \"\") { Set-TimeZone -Name \"${var.time_zone}\" }"
    ]
  }

  provisioner "powershell" {
    inline = [
      "Write-Host 'Waiting for system to stabilize...'",
      "Start-Sleep -Seconds 10"
    ]
  }

  # Create admin-deploy account with injected password
  provisioner "powershell" {
    inline = [
      "$user = '${var.admin_deploy_username}'",
      "$password = '${var.admin_deploy_password}'",
      "$secPassword = ConvertTo-SecureString $password -AsPlainText -Force",
      "New-LocalUser -Name $user -Password $secPassword -PasswordNeverExpires -Description 'Admin deployment account'",
      "Add-LocalGroupMember -Group 'Administrators' -Member $user",
      "$password = $null; $secPassword = $null"
    ]
  }



  # Runs RIGHT BEFORE sysprep to ensure clean state (Dummy script for now)
  provisioner "powershell" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File C:\\bootstrap\\scripts\\packerRun_Prepare-ForSysprep.ps1"
    ]
  }
}
