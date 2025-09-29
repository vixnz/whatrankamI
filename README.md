# 🚀 Windows Auto-Install System

*Created & maintained by [vixnz](https://github.com/vixnz)*

Automate Windows installs from Linux with zero user interaction. Skip the manual steps, let your machine do the work, and get a fresh Windows environment in minutes.

---

## 🌟 What is this?

**Windows Auto-Install System** is a complete framework that turns your Linux PC into a Windows deployment powerhouse. Plug in a USB, point to a Windows ISO, and go from “blank drive” to “ready-to-use desktop”—all hands-free.

---

## 🏆 Why Use This?

- **Truly Unattended Installs** – No keyboard or mouse needed during setup.
- **Automatic USB Creation** – Bootable media with a single command.
- **Boot Priority Magic** – Reboots and boots from your USB without BIOS fiddling.
- **Works Everywhere** – Supports UEFI & legacy BIOS systems.
- **Enterprise-Ready** – Uses Microsoft’s official answer file format.
- **Resume Any Step** – Pick up where you left off if interrupted.
- **Flexible USB Methods** – Works with Ventoy or direct disk writing.

---

## 🧰 Requirements

- **Linux system** with root access
- **USB drive** (8GB or larger)
- **Windows ISO** (official, not modified)
- **Free disk space:** ~4GB+
- **Dependencies:**  
  Ubuntu/Debian:
  ```bash
  sudo apt install p7zip-full genisoimage wimtools efibootmgr parted dosfstools
  ```
  Arch, Fedora, and others—see below for details.

- **Optional:** [Ventoy](https://github.com/ventoy/Ventoy) for multi-ISO USB.

---

## 🚦 Quick Start

1. **Clone the Repo**
   ```bash
   git clone <repository_url>
   cd windows-auto-install
   ```
2. **Start the Install**
   ```bash
   sudo ./auto-install.sh /path/to/Windows11.iso
   ```
   - Creates an unattended ISO
   - Prepares your USB drive
   - Sets boot priority
   - Reboots into Windows setup

3. **Let It Run**
   - The PC restarts and installs Windows automatically
   - You’ll land at the desktop with an admin account (`admin` / `admin123`)

**Average time:** 15–45 minutes (hardware-dependent)

---

## 🗂️ Project Layout

```
windows-auto-install/
├── auto-install.sh         # Main automation script
├── scripts/                # Helper scripts
│   ├── create-iso.sh       # Make unattended ISO
│   ├── create-usb.sh       # Write USB
│   └── boot-setup.sh       # Handle boot priority
├── config/                 # Configuration files
│   ├── autounattend.xml    # Windows answer file
│   └── settings.conf       # Your settings
├── temp/                   # Temporary stuff
└── backup/                 # Boot config backups
```

---

## ⚙️ Configuration

**Edit `config/settings.conf` to personalize:**
```bash
USB_METHOD=ventoy         # or 'dd'
ADMIN_USERNAME=admin      # change this!
ADMIN_PASSWORD=admin123   # please change this :)
COMPUTER_NAME=Windows-Auto
AUTO_PARTITION=true
SKIP_OOBE=true
REBOOT_DELAY=10
```

---

## 🤖 Advanced Usage

- **Step-by-step execution:**
  ```bash
  sudo ./auto-install.sh --step1 /path/to/Windows11.iso
  sudo ./auto-install.sh --step2 Windows-Unattended.iso
  sudo ./auto-install.sh --step3
  sudo ./auto-install.sh --step4
  ```
- **Use helper scripts directly:**  
  See the original README for full details.

---

## 🔍 How Does It Work?

1. **Unattended Setup:**  
   Uses Microsoft’s official answer file (`autounattend.xml`) to automate everything, from partitioning to user creation and post-install tweaks.

2. **USB Creation:**  
   - **Ventoy mode**: Multi-boot USB for all your ISOs
   - **DD mode**: Direct image copy for max compatibility

3. **Boot Management:**  
   - UEFI: Sets next boot device automatically
   - BIOS: Gives you clear guidance, plus recovery options

---

## 🎯 Supported Windows Versions

- Windows 11 (all editions)
- Windows 10 (all editions)
- Windows Server 2022, 2019, 2016

---

## 🆘 Troubleshooting

- **USB not detected:**  
  Use `lsblk` and `sudo fdisk -l`, check `/sys/block/sdX/removable` (should be “1”).

- **ISO creation fails:**  
  Double-check dependencies, validate ISO integrity with `7z l /path/to/Windows.iso | grep setup.exe`.

- **Boot config fails:**  
  Use `efibootmgr` for UEFI, check `/sys/firmware/efi` for boot mode.

- **Windows hangs:**  
  Disable Secure Boot, try different USB ports, check RAM, verify ISO.

- **Recovery:**  
  Restore boot (`./scripts/boot-setup.sh --restore`), reset state (`./auto-install.sh --reset`), cleanup temp files.

---

## 🔒 Security Tips

- **Default credentials:**  
  `admin` / `admin123` (change ASAP!)
- **Answer file** contains plaintext passwords—secure it:
  ```bash
  chmod 600 config/autounattend.xml
  ```
- **After install:**  
  - Change password
  - Enable Defender & Firewall
  - Remove auto-login

---

## 📝 Customization

- **Edit `autounattend.xml`:**  
  Customize accounts, computer name, post-install scripts, regional settings.
- **Post-install PowerShell:**  
  Add your own commands for automation.
- **Choose edition for multi-ISO:**  
  Specify in the answer file.

---

## 🏢 For IT Pros & Enterprises

- **Batch deploy:**  
  Use SSH to automate installs across multiple machines.
- **Network deploy:**  
  PXE boot, Windows Deployment Services, SCCM supported.
- **Domain join:**  
  Add details to the answer file for automatic AD join.

---

## 🤝 Contributing

This repo is **proprietary**—viewing and personal use welcome, but redistribution/derivative works are not.  
Want to help?  
- Open an issue to discuss
- Contact vixnz for permission
- All contributions become property of vixnz

See `CONTRIBUTING.md` for details.

---

## 📄 License

**Copyright © 2025 vixnz. All rights reserved.**  
Custom restrictive license—see LICENSE for details.

- Personal/educational use: ✅
- Internal business use: ✅
- Redistribution/resale: ❌
- Commercial redistribution: ❌
- Modification & redistribution: ❌

For commercial licensing, contact vixnz.

---

## ⚠️ Disclaimer

- This tool **erases data** on target drives & USBs
- Backup first!
- Test in VMs before production use
- Use at your own risk—no liability for data loss

---

## 🆘 Support

- Check troubleshooting above
- Review existing GitHub issues
- Create a new issue (include Linux distro, hardware, ISO details, exact errors, steps to reproduce)

**Enable verbose logging for debugging:**
```bash
export DEBUG=1
sudo ./auto-install.sh Windows11.iso
journalctl -f
dmesg | tail -50
```

---

## 👤 Author

**vixnz** — Creator & maintainer

---

## 🔗 Links

- [GitHub Repository](https://github.com/vixnz/whatrankamI)
- [Report Issues](https://github.com/vixnz/whatrankamI/issues)
- Contact via GitHub for licensing or questions

---

**🎉 Enjoy a truly automated Windows install & a faster setup workflow!**

*Windows Auto-Install System — proprietary software by vixnz*
