# Shared defaults (auto-loaded)
# primary_iso        = "../../iso/customized/SERVER_2025_30_10_efisys_noprompt.bin.iso"
# output_base_path   = "../../output"

# Must be passed at runtime (environment-dependent)
iso_checksum         = "none"
ssh_private_key_file = "none"

# Edition-specific (set via per-edition vars files)
vm_name       = "none" # resolves to e.g windows_server_2025_core or _standard
secondary_iso = "none" # .. files/windows_server_2025_core/secondary_iso.iso

# Hyper-V defaults
hyperv_switch_name = "Default Switch"
hyperv_generation  = 2
vm_cpus            = 4 
vm_memory          = 8192
enable_secure_boot = true

# Communicator/timeouts
admin_username   = "packer"
ssh_timeout      = "2h"
shutdown_timeout = "60m"


