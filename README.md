# Windows Auto-Install System

Automate Windows install from Linux—no clicks, no fuss.

**How it works:**
1. Plug in USB, get official Windows ISO.
2. Run:  
   `sudo ./auto-install.sh /path/to/Windows11.iso`
3. PC reboots, Windows installs itself, admin account ready.

**Needs:**  
- Linux (root), USB (8GB+), official ISO  
- Install deps:  
  `sudo apt install p7zip-full genisoimage wimtools efibootmgr parted dosfstools`

**Default login:**  
admin / admin123 (change this!)

**Supports:**  
Win 10/11, Server 2016+

**Caution:**  
Wipes drives. Backup first!
