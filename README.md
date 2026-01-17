# Template Builder

## Table of Contents

- [Quick Note](#quick-note)
- [What It Does](#what-it-does)
- [Prerequisites](#prerequisites)
- [Usage](#usage-example)
- [Project Structure](#project-structure)
- [Customization](#customization)
- [Technical Notes](#technical-notes)
- [Acknowledgements](#acknowledgements)

## Quick Note
- Builds Windows Server 2025 template ("golden image"); from download to final export as `.vhdx`.
- Whole process is automated.
- Not hardened; intended for lab/test Hyper-V use. **But can be customized to provide hardening.**
- Uses Packer, works on Hyper-V, connects to VM via SSH (SSH communicator is used, not WinRM).
- Provisioned `svc-deploy` admin\service account during first boot; to be used with pub\priv key authentication via SSH.

## Prerequisites
- Windows 10/11/Server with Hyper-V enabled.
- Packer 1.8+ on PATH.
- PowerShell 5.1+ (PS 7 recommended).
- Windows ADK (for `efisys_noPrompt.bin`) - script by default expects ADK at `C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\` (override via `-NoPromptBootFile`).
- Sufficient disk space (~30 GB per template + ISOs).
- SSH client (Should be provided with Windows feature OpenSSH)

## What It Does
### 1) Downloads the selected Windows ISO and verifies SHA256.

Works for Windows Server 2025 Evaluation. Expected SHA256 related to download link is defined in `files\windows\windows_image_catalog.json`

### 2) Generates custom no-prompt ISO variant
Uses no-prompt boot file (`efisys_noPrompt.bin`) from Windows ADK, to skip “Press any key to boot…” prompts reliably (as Packer `boot_command` may not always work).

### 3) Builds a secondary (provisioning) ISO with autounattend.xml, unattend.xml, bootstrap and first-boot scripts.
**Autounattend selection:** build-specific `autounattend.xml` (Standard\Datacenter, Core\GUI) is copied as `autounattend.xml` to `secondary_iso.iso`.
**Provisioning payload:** `bootstrap.ps1`, `unattend.xml`, scripts, settings, and sshd config are copied to a temp directory, then whole directory is packed into `secondary_iso.iso`.

### 4) Runs Packer (Hyper-V provider, Gen2, UEFI) using primary + secondary ISOs to create a ready-to-use template.

Installation flow is driven by the autounattend from step 3; customization lives in `bootstrap.ps1`.
By virtue of the no_prompt ISO from step 2, no `boot_command` or manual intervention is needed.
`autounattend.xml` calls `bootstrap.ps1`. `bootstrap.ps1`:
* Installs Scoop (package manager, can be used for automated provisioning on finalized VM) 
* PowerShell 7 (pwsh)
* CLI tools (`micro` text editor, `far` file manager, `bat` cat with colours) for more convenient interactive SSH sessions.
* Runs UI/CLI tweaks (don’t start Server Manager, custom prompt, etc.).
* Runs `Enable-Connector-SSH_packer.ps1` to install/configure sshd for Packer and later access.
* Copies `unattend.xml` to `C:\Windows\System32\Sysprep\`, `unattend.xml` defines first-boot behavior.

After SSH connection is established, Packer connects and runs script to prepare template for sysprep (currently just dummy script).

### 5) Prepares the template for capture (sysprep).
Sysprep generalizes the image (referencing `unattend.xml`), then Packer exports the template as `.vhdx`.

---

### 6) Post-build
From template, new VMs are created using **differential disks** (parent/child VHDX).

**Offline SSH key injection**: Mount the differential disk, inject SSH public key to `C:\bootstrap\svc-deploy\authorized_keys`, which `FirstBoot.ps1` copies to `svc-deploy` user's `.ssh\authorized_keys` during first boot (no WinRM/credentials needed pre-boot).

See `usage_examples\Create-VMwithSshKey.ps1` for complete workflow example.

Then, when VM is first started:
**Unattend.xml orchestrates first boot**: Runs `FirstBoot.ps1` which creates `svc-deploy` admin account with random password (logged), sets up SSH authorized_keys structure for offline injection, and finalizes SSH configuration.

## Usage (Example)
Clone or otherwise download repo.

Navigate to `<repo_root>\build_template`.
From here, run one of the scripts:

* build_WINDOWS_SERVER_2025_EVAL_DATACENTER_CORE.ps1
* build_WINDOWS_SERVER_2025_EVAL_DATACENTER_GUI.ps1
* build_WINDOWS_SERVER_2025_EVAL_STANDARD_CORE.ps1
* build_WINDOWS_SERVER_2025_EVAL_STANDARD_GUI.ps1

Scripts cover all possible combinations of editions and experiences for Windows Server 2025 Evaluation ISO (Standard\Datacenter, Core\GUI).

Options are \ reflect what you'll see if you mount .iso and enumerate images: 
```powershell
dism /Get-WimInfo /WimFile:"$drive:\sources\install.wim"
```

You can switch Windows editions — from Standard → Datacenter or Evaluation → Paid after you build VM.

The scripts are just "wrappers" to call `...\pipelines\Build-WindowsTemplate.ps1`. There is no need to call the pipeline directly with parameters, as all implemented options are covered. Run `Get-Help .\Build-WindowsTemplate.ps1 -Detailed` or check script itself for details.

Here is explanation of some parameters, in case you need to run them more than once or adjust:
```powershell
Build-WindowsTemplate.ps1 `
    -IsoId "WINDOWS_SERVER_2025_EVAL" ` # One of possible ids from .json catalog file
    -ImageOption "Windows Server 2025 Datacenter Evaluation" ` # one of possible images stored in .wim file on .iso
    -OverwriteDownloadedIso $false `
    -CompareChecksums $true ` # validates download, makes sense to change to $false after first download
    -Use_No_Prompt_Iso $true `
    -OverwriteNoPromptIso $false `
    -NoPromptBootFile = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\efisys_noPrompt.bin" 
    # NoPromptBootFile defaults to where Windows ADK is expected to be installed, needs only efisys_noPrompt.bin
```

After build is done, check output for generated artifacts, namely `output\packer\windows_server_2025_..your...build\` for .vhdx.

Use as parent disk for new differential, inject there `<drive>\\bootstrap\svc-deploy\authorised_keys` (with content of `$env:USERPROFILE\.ssh\ed25519_svc-deploy_hyperv_vm.pub`) to be used by `svc-deploy`, set new VM to boot from new disk.

This can be done by script or via Terraform (example using `null_resource` with `local-exec` provisioner):

```hcl
resource "null_resource" "inject_ssh_key" {
  provisioner "local-exec" {
    command = "powershell -NoProfile -Command & '${path.module}/Mount-DiskAndInjectSSHKey.ps1' -VhdPath '${hyperv_vhd.my_vhd.path}' -PublicKeyPath '$${env:USERPROFILE}/.ssh/ed25519_svc-deploy_hyperv_vm.pub'"
  }
}
```

Example script which mount new vhdx, injects and build machine - `usage_examples\Create-VMwithSshKey.ps1`

You can test if it works via 
```powershell
ssh -i $env:USERPROFILE\.ssh\ed25519_svc-deploy_hyperv_vm svc-deploy@<IP of new VM>
```

## Project Structure

### Key Files
- `build_template\pipelines\Build-WindowsTemplate.ps1` — Main entrypoint orchestrating the entire build process.
- `build_template\helpers\` — Helper scripts:
  - `Download-WindowsIso.ps1` — Downloads and validates ISO checksums
  - `New-NoPromptIso.ps1` — Injects `efisys_noPrompt.bin` into ISO
  - `New-IsoFile.ps1` - Creates new ISO
  - `Invoke-PackerBuild.ps1` — Launches Packer with validated variables
  - `Ensure-SshKeyPair.ps1` — Generates SSH keys for Packer communicator
- `top_dir` — Determines top directory of repo  

### Configuration & Content
- `files\windows\windows_image_catalog.json` — Single source of truth: ISO URLs, SHA256, editions, autounattend mappings. 
- `files\windows\autounattend\` — Unattended install XMLs (per edition/SKU). Build-specific files selected by catalog.
- `files\windows\bootstrap.ps1` — Orchestrates provisioning steps inside the VM (installs scoop, pwsh, configures SSH, tweaks UI).
- `files\windows\scripts\` — Individual provisioning scripts:
  - `Enable-Connector-SSH_packer.ps1` — Installs and configures OpenSSH for Packer
  - `FirstBoot.ps1` — Creates `svc-deploy` account, sets up SSH keys (runs post-sysprep)
  - `packerRun_Prepare-ForSysprep.ps1` — Pre-sysprep cleanup
- `packer\windows\` — Packer HCL definitions and `.auto.pkrvars.hcl` variable overrides. 

### Output Directories
- `iso\original\` — Downloaded Microsoft ISOs. See [iso/original/original_iso.md](iso/original/original_iso.md).
- `iso\no_prompt\` — Generated no-prompt variants with `efisys_noPrompt.bin`. See [iso/no_prompt/No_Prompt_iso.md](iso/no_prompt/No_Prompt_iso.md).
- `output\<build_name>\secondary_iso\` — Staging directory for secondary ISO contents.
- `output\packer\<template_name>\` — Final templates (VHDX + Hyper-V VM configs).

## Customization
- Add/modify autounattend XMLs and reference them in `windows_image_catalog.json`.
- Extend provisioning by adding scripts to `files\windows\scripts\` and referencing them in `bootstrap.ps1`.
- Define what happens during finalised VM first start, call custom scripts from `files\windows\scripts\FirstBoot.ps1`  
- Adjust Packer variables in `packer\windows\*.auto.pkrvars.hcl` (CPU, RAM, switch).

## Technical Notes

### Windows Updates
**Updates** aren't provided during instalation \ build.
Nor I did experienced any updates interferece with installation process so far.
Finalized template reflects the update level at ISO time of release.

**Possible ways to install updates:**
- Inject updates into custom ISO before build: [Add updates MSU offline into Windows images WIM](https://4sysops.com/archives/add-updates-msu-offline-into-windows-images-wim/)
- Install updates before sysprep (by running script to update OS from `bootstrap.ps1`, before sysprep, easier to implement.)

### Security Hardening 
- **None implemented.** (Can be done by running script to update OS from `bootstrap.ps1`, before sysprep)

### Boot Order & ISO Handling
- **Primary ISO** (Windows installation media) boots first via Hyper-V DVD drive.
- **Secondary ISO** (provisioning media) is attached as second DVD drive, available after Windows PE boots.
- `efisys_noPrompt.bin` avoids "Press any key to boot…" prompt (more reliable than Packer `boot_command` which requires enhanced session disabled and precise timing).

### Packer Hash Validation

Packer warns about a null hash for the primary DVD (no_prompt ISO variant), which is expected. 

SHA256 validation confirms that the downloaded file matches the one published online. 
But, the no_prompt ISO is generated from the original Windows ISO; `New-IsoFile.ps1` retrieves the content of the original downloaded ISO and creates a new one with a different boot file. Many factors affect the SHA256 of the resulting ISO file, so the no_prompt ISO hash cannot be compared to any predetermined value.

The original Windows ISO undergoes SHA256 validation at the start of the build process (see [What It Does, Step 1](#1-downloads-the-selected-windows-iso-and-verifies-sha256)). To skip this validation after the first download, use `-CompareChecksums $false`:

```powershell
Build-WindowsTemplate.ps1 -IsoId "WINDOWS_SERVER_2025_EVAL" -ImageOption "Windows Server 2025 Datacenter Evaluation" -CompareChecksums $false
```

If the SHA256 of the no_prompt ISO were deterministic, it could verify whether `New-IsoFile.ps1` created a valid ISO file with an exact SHA256. If necessary, `oscdimg.exe` from the Windows ADK can create bootable ISO files and validate them by means other than SHA256 comparison. DISM tools could also help. 

Anyway, so far, I have not experienced any issues with no_prompt iso, so validation is probably not necessary. 

### SSH Connection

**During build**:
- `Enable-Connector-SSH_packer.ps1` installs sshd, configures firewall, sets authorized_keys for `packer` user
- Packer connects via `$env:USERPROFILE\.ssh\ed25519_packer_hyperv_vm` key

**Post-deployment** (manually, script, or Terraform `local-exec`):
- Mount differential disk offline, inject pub key to `C:\bootstrap\svc-deploy\authorized_keys`
- On first boot: `FirstBoot.ps1` creates `svc-deploy` admin account, copies key to `C:\Users\svc-deploy\.ssh\authorized_keys`
- Test connection: `ssh -i $env:USERPROFILE\.ssh\ed25519_svc-deploy_hyperv_vm svc-deploy@<VM_IP>`

- `svc-deploy` created with 35-character random password (not logged nor writen to console) + pub/priv key authentication.
- `svc-deploy` is intended for Terraform, Ansible, scripts, and other automation.

### Edition Switching
You can upgrade Windows editions post-build:
- Standard → Datacenter but not vice versa.
- Evaluation → Paid: Provide valid license key after deployment.

Commands to upgrade edition (powershell):
```powershell
# List available editions for upgrade
DISM /Online /Get-TargetEditions

# Upgrade to target edition (e.g., ServerDatacenter)
DISM /Online /Set-Edition:ServerDatacenter /ProductKey:XXXXX-XXXXX-XXXXX-XXXXX-XXXXX /AcceptEula
```

### Evaluation Period
You can check remainding days by running (cmd):
```cmd
cscript //Nologo C:\Windows\System32\slmgr.vbs /dli
cscript //Nologo C:\Windows\System32\slmgr.vbs /xpr
```

Evaluation period starts when VM is build.

## Acknowledgements

### Third-Party Scripts
`New-IsoFile.ps1` - Slight edit of [script by TheDotSource ](https://github.com/TheDotSource/New-ISOFile)

