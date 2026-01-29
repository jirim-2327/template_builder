temp_path = "D:\\Packer_Temp\\"

# Disable VHDX compaction/optimization after build
# skip_compaction = true

# If true Packer will skip the export of the VM. If you are interested only in the VHD/VHDX files, you can enable this option.
skip_export =  true

# headless = true

# should be faster a bit? 
enable_secure_boot = false

# don't know if this impact performance
enable_dynamic_memory = false

# should keep the machine after so it can be investigated
keep_registered = true

shutdown_timeout = "60m"