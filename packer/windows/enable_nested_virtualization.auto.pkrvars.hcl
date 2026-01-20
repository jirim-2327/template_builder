# Nested Virtualization Profile
# Required settings for VMs that will run Hyper-V
# 
# For nested virtualisation:
# - enable_virtualization_extensions
# - enable_mac_spoofing
# - disable dynamic memory (configured at Hyper-V level)
# - at least 4GB of RAM assigned to the virtual machine

enable_virtualization_extensions = true
enable_mac_spoofing = true
vm_memory = 8192
vm_cpus = 4
enable_dynamic_memory = false
