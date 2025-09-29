# Windows Auto-Install System

**Created by vixnz**

A complete automation framework for installing Windows from Linux with zero user interaction.

## 🚀 Features

- **100% Unattended Installation** - No user input required during Windows setup
- **Automated USB Creation** - Creates bootable installation media automatically  
- **Boot Priority Management** - Configures system to boot from installation media
- **UEFI & BIOS Support** - Works with both modern and legacy systems
- **Enterprise-Grade** - Uses Microsoft's official unattended installation methods
- **Resume Capability** - Can resume from any step if interrupted
- **Multiple USB Methods** - Supports both Ventoy and direct DD methods

## 📋 Requirements

### System Requirements
- Linux system with root access
- 8GB+ USB drive
- 4GB+ free disk space
- Original Windows ISO file

### Dependencies
```bash
# Ubuntu/Debian
sudo apt install p7zip-full genisoimage wimtools efibootmgr parted dosfstools

# Arch Linux  
sudo pacman -S p7zip cdrkit wimlib efibootmgr parted dosfstools

# Fedora/RHEL
sudo dnf install p7zip genisoimage wimlib efibootmgr parted dosfstools
```

### Optional (for Ventoy method)
```bash
# Ubuntu/Debian
sudo apt install ventoy

# Or download from: https://github.com/ventoy/Ventoy
```

## 🔧 Quick Start

### 1. Download and Setup
```bash
git clone <repository_url>
cd windows-auto-install
```

### 2. Run Complete Installation
```bash
# Full automated installation (recommended)
sudo ./auto-install.sh /path/to/Windows11.iso

# This will:
# - Create unattended Windows ISO
# - Create bootable USB drive  
# - Configure boot priority
# - Automatically reboot to Windows installer
```

### 3. Windows Installs Automatically
- System reboots from USB
- Windows installs without any user input
- Creates admin account: `admin` / `admin123`
- Boots to desktop ready for use

**Total time: 15-45 minutes (depending on hardware)**

## 📁 Project Structure

```
windows-auto-install/
├── auto-install.sh           # Main automation script
├── scripts/
│   ├── create-iso.sh         # Creates unattended Windows ISO
│   ├── create-usb.sh         # Creates bootable USB drive
│   └── boot-setup.sh         # Configures boot priority
├── config/
│   ├── autounattend.xml      # Windows answer file
│   └── settings.conf         # User configuration
├── temp/                     # Temporary files
└── backup/                   # Boot configuration backups
```

## ⚙️ Configuration

Edit `config/settings.conf` to customize:

```bash
# USB Creation Method (ventoy or dd)
USB_METHOD=ventoy

# User account settings (CHANGE THESE!)
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
COMPUTER_NAME=Windows-Auto

# Installation settings
AUTO_PARTITION=true
SKIP_OOBE=true
REBOOT_DELAY=10
```

## 🛠️ Advanced Usage

### Step-by-Step Execution
```bash
# Step 1: Create unattended ISO only
sudo ./auto-install.sh --step1 /path/to/Windows11.iso

# Step 2: Create USB only (requires unattended ISO)
sudo ./auto-install.sh --step2 Windows-Unattended.iso

# Step 3: Configure boot priority only
sudo ./auto-install.sh --step3

# Step 4: Reboot to Windows installer
sudo ./auto-install.sh --step4
```

### Individual Scripts
```bash
# Create unattended ISO manually
sudo ./scripts/create-iso.sh /path/to/Windows11.iso MyWindows.iso

# Create USB manually
sudo ./scripts/create-usb.sh Windows-Unattended.iso /dev/sdb ventoy

# Configure boot manually
sudo ./scripts/boot-setup.sh --auto
```

### Status and Management
```bash
# Check installation status
sudo ./auto-install.sh --status

# Reset installation state
sudo ./auto-install.sh --reset

# Edit configuration
sudo ./auto-install.sh --config

# Restore boot configuration
sudo ./scripts/boot-setup.sh --restore
```

## 🔍 How It Works

### 1. Unattended Installation
- Uses Microsoft's `autounattend.xml` format
- Configures automatic partitioning (UEFI: EFI + MSR + Windows)
- Sets up user accounts and skips OOBE screens
- Runs post-installation commands

### 2. USB Creation  
- **Ventoy Method**: Creates multi-boot USB that can hold multiple ISOs
- **DD Method**: Direct bit-for-bit copy for maximum compatibility
- Automatically detects USB devices and validates size

### 3. Boot Management
- **UEFI Systems**: Uses `efibootmgr` to set next boot device
- **BIOS Systems**: Provides guidance for BIOS configuration
- Backs up original boot configuration for recovery

## 🎯 Supported Windows Versions

- ✅ Windows 11 (all editions)
- ✅ Windows 10 (all editions)  
- ✅ Windows Server 2022
- ✅ Windows Server 2019
- ✅ Windows Server 2016

## 🔧 Troubleshooting

### Common Issues

#### USB Not Detected
```bash
# Check USB devices
lsblk
sudo fdisk -l

# Ensure USB is removable
cat /sys/block/sdb/removable  # Should output "1"
```

#### ISO Creation Fails  
```bash
# Install missing dependencies
sudo apt install p7zip-full genisoimage wimtools

# Check ISO integrity
7z l /path/to/Windows.iso | grep -i setup.exe
```

#### Boot Configuration Fails
```bash
# Check boot system
[ -d "/sys/firmware/efi" ] && echo "UEFI" || echo "BIOS"

# Manual UEFI boot entry
sudo efibootmgr -v  # List entries
sudo efibootmgr -n 0001  # Set next boot
```

#### Windows Installation Hangs
- Ensure Secure Boot is disabled in UEFI
- Try different USB port (USB 2.0 if USB 3.0 fails)
- Check RAM integrity (run memtest)
- Verify Windows ISO is not corrupted

### Recovery Commands
```bash
# Restore original boot order
sudo ./scripts/boot-setup.sh --restore

# Clean up and start over
sudo ./auto-install.sh --reset
rm -f Windows-Unattended.iso

# Manual cleanup
sudo umount /dev/sdb* 2>/dev/null || true
rm -rf temp/
```

## 🔒 Security Considerations

### Default Credentials
```
Username: admin
Password: admin123
```

**⚠️ IMPORTANT**: Change these credentials immediately after installation!

### Post-Installation Security
1. Change administrator password
2. Enable Windows Defender
3. Install latest Windows updates  
4. Configure Windows Firewall
5. Remove auto-login (if enabled)

### Answer File Security
The `autounattend.xml` contains plaintext passwords. Protect this file:
```bash
chmod 600 config/autounattend.xml
```

## 📝 Customization

### Custom Answer File
Edit `config/autounattend.xml` to customize:
- User accounts and passwords
- Computer name and organization
- Installed Windows components
- Post-installation commands
- Regional settings

### Custom Post-Install Scripts
Add PowerShell commands in `autounattend.xml`:
```xml
<SynchronousCommand wcm:action="add">
    <CommandLine>powershell.exe -Command "Your-Command-Here"</CommandLine>
    <Description>Custom command description</Description>
    <Order>10</Order>
</SynchronousCommand>
```

### Windows Edition Selection
For multi-edition ISOs, specify edition in answer file:
```xml
<MetaData wcm:action="add">
    <Key>/IMAGE/NAME</Key>
    <Value>Windows 11 Pro</Value>
</MetaData>
```

## 🏢 Enterprise Use

### Batch Deployment
```bash
# Deploy to multiple machines
for machine in machine1 machine2 machine3; do
    ssh root@$machine "cd /path/to/windows-auto-install && ./auto-install.sh Windows11.iso"
done
```

### Network Deployment
- Set up PXE boot server with unattended ISO
- Use Windows Deployment Services (WDS)
- Deploy via SCCM or similar tools

### Domain Join
Add domain join commands to answer file:
```xml
<component name="Microsoft-Windows-UnattendedJoin">
    <Identification>
        <JoinDomain>yourdomain.com</JoinDomain>
        <DomainAdmin>domainadmin</DomainAdmin>
        <DomainAdminPassword>password</DomainAdminPassword>
    </Identification>
</component>
```

## 🤝 Contributing

**Note: This is proprietary software by vixnz.**

While this repository is public for viewing and personal use, redistribution and derivative works are not permitted. If you'd like to contribute:

1. Open an issue to discuss proposed changes
2. Contact vixnz for permission to contribute
3. All contributions become property of vixnz
4. Contributors must agree to transfer all rights to vixnz

See CONTRIBUTING.md for detailed guidelines.

## 📄 License & Copyright

**Copyright (c) 2025 vixnz. All rights reserved.**

This project is licensed under a custom restrictive license. See LICENSE file for complete terms.

**Key Points:**
- ✅ Personal and educational use permitted
- ✅ Internal business use allowed
- ❌ **NO redistribution or resale permitted**
- ❌ **NO commercial redistribution**
- ❌ **NO modification and redistribution**

For commercial licensing or permissions beyond this scope, contact vixnz through the repository.

## ⚠️ Disclaimer

- This tool will **erase data** on target drives and USB devices
- Always backup important data before use
- Test in virtual machines before production use
- Use at your own risk - authors not responsible for data loss

## 🆘 Support

### Getting Help
1. Check the troubleshooting section above
2. Search existing GitHub issues
3. Create a new issue with:
   - Linux distribution and version
   - Hardware specifications  
   - Windows ISO details
   - Complete error messages
   - Steps to reproduce

### Logs and Debugging
```bash
# Enable verbose logging
export DEBUG=1
sudo ./auto-install.sh Windows11.iso

# Check system logs
journalctl -f
dmesg | tail -50
```

---

## 👤 Author

**vixnz** - Creator and maintainer of Windows Auto-Install System

## 🔗 Links

- **Repository**: [GitHub Repository]
- **Issues**: Report bugs and request features via GitHub Issues
- **Contact**: Reach out through GitHub for licensing questions

---

**🎉 Enjoy your fully automated Windows installation!**

*Windows Auto-Install System - Proprietary software by vixnz*
