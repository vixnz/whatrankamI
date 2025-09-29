#!/bin/bash
# Copyright (c) 2025 vixnz. All rights reserved.
# Windows Auto-Install System - Boot Configuration Script
#
# This file is part of the Windows Auto-Install System.
# Unauthorized distribution is prohibited.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${PURPLE}[INFO]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        echo "Example: sudo $0"
        exit 1
    fi
}

# Detect boot system (UEFI or BIOS)
detect_boot_system() {
    log "Detecting boot system..."
    
    if [ -d "/sys/firmware/efi" ]; then
        echo "uefi"
        success "UEFI system detected"
    else
        echo "bios"
        success "BIOS/Legacy system detected"
    fi
}

# Get UEFI boot entries
get_uefi_entries() {
    log "Getting UEFI boot entries..."
    
    if ! command -v efibootmgr &> /dev/null; then
        error "efibootmgr not found. Install with: apt install efibootmgr"
        return 1
    fi
    
    local entries
    entries=$(efibootmgr -v 2>/dev/null || echo "")
    
    if [ -z "$entries" ]; then
        error "Could not retrieve UEFI boot entries"
        return 1
    fi
    
    echo "$entries"
}

# Find USB boot entry
find_usb_entry() {
    local entries="$1"
    
    log "Looking for USB boot entries..."
    
    # Common USB identifiers
    local usb_patterns=("USB" "usb" "Removable" "removable" "UEFI:" "Flash" "Kingston" "SanDisk" "Generic")
    
    local usb_entries=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^Boot[0-9A-F]{4} ]]; then
            local entry_num=$(echo "$line" | grep -o 'Boot[0-9A-F]\{4\}' | sed 's/Boot//')
            
            for pattern in "${usb_patterns[@]}"; do
                if [[ "$line" =~ $pattern ]]; then
                    usb_entries+=("$entry_num:$line")
                    break
                fi
            done
        fi
    done <<< "$entries"
    
    if [ ${#usb_entries[@]} -eq 0 ]; then
        warning "No USB boot entries found automatically"
        return 1
    fi
    
    # Show found entries
    echo "Found USB boot entries:"
    for i in "${!usb_entries[@]}"; do
        local entry="${usb_entries[$i]}"
        local num=$(echo "$entry" | cut -d: -f1)
        local desc=$(echo "$entry" | cut -d: -f2-)
        echo "  $((i+1)). Boot$num - $desc"
    done
    
    # Return first entry number
    echo "${usb_entries[0]}" | cut -d: -f1
}

# Show all boot entries for manual selection
show_boot_entries() {
    local entries="$1"
    
    echo "All available boot entries:"
    echo "$entries" | grep -E '^Boot[0-9A-F]{4}' | while IFS= read -r line; do
        local entry_num=$(echo "$line" | grep -o 'Boot[0-9A-F]\{4\}' | sed 's/Boot//')
        echo "  $entry_num - $line"
    done
}

# Set UEFI next boot
set_uefi_next_boot() {
    local boot_entry="$1"
    
    log "Setting next boot to: Boot$boot_entry"
    
    if efibootmgr -n "$boot_entry" &> /dev/null; then
        success "Next boot set to Boot$boot_entry"
        return 0
    else
        error "Failed to set next boot entry"
        return 1
    fi
}

# Handle GRUB boot (BIOS systems)
handle_grub_boot() {
    log "Configuring GRUB for USB boot..."
    
    local grub_cfg="/boot/grub/grub.cfg"
    local grub_default="/etc/default/grub"
    
    if [ ! -f "$grub_cfg" ]; then
        error "GRUB configuration not found"
        return 1
    fi
    
    # Look for USB entries in GRUB
    local usb_entries
    usb_entries=$(grep -i "menuentry.*usb\|menuentry.*removable" "$grub_cfg" || echo "")
    
    if [ -n "$usb_entries" ]; then
        echo "Found USB entries in GRUB:"
        echo "$usb_entries"
        warning "You may need to manually select USB boot from GRUB menu"
    else
        warning "No USB entries found in GRUB"
        echo "You will need to:"
        echo "1. Reboot and enter BIOS/UEFI setup"
        echo "2. Set USB as first boot device"
        echo "3. Save and exit"
    fi
    
    return 0
}

# Backup current boot configuration
backup_boot_config() {
    log "Backing up boot configuration..."
    
    local backup_dir="$PROJECT_DIR/backup"
    mkdir -p "$backup_dir"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [ -d "/sys/firmware/efi" ]; then
        # UEFI system
        efibootmgr -v > "$backup_dir/efiboot_backup_$timestamp.txt" 2>/dev/null || true
        success "UEFI boot configuration backed up"
    else
        # BIOS system
        if [ -f "/etc/default/grub" ]; then
            cp "/etc/default/grub" "$backup_dir/grub_default_backup_$timestamp"
        fi
        success "GRUB configuration backed up"
    fi
}

# Restore boot configuration
restore_boot_config() {
    local backup_dir="$PROJECT_DIR/backup"
    
    log "Available backups:"
    if [ -d "$backup_dir" ]; then
        ls -la "$backup_dir" | grep backup || echo "No backups found"
    else
        echo "No backup directory found"
    fi
    
    warning "To restore UEFI boot order manually, use: efibootmgr -o XXXX,YYYY,ZZZZ"
    echo "Where XXXX,YYYY,ZZZZ are boot entry numbers in desired order"
}

# Wait and reboot
reboot_system() {
    local delay="${1:-10}"
    
    echo
    warning "System will reboot in $delay seconds..."
    echo "Press Ctrl+C to cancel"
    
    for ((i=delay; i>=1; i--)); do
        echo -ne "\rRebooting in $i seconds... "
        sleep 1
    done
    
    echo
    log "Rebooting system..."
    reboot
}

# Interactive mode
interactive_mode() {
    echo "========================================"
    echo "          Interactive Boot Setup"
    echo "========================================"
    
    local boot_system
    boot_system=$(detect_boot_system)
    echo
    
    if [ "$boot_system" = "uefi" ]; then
        local entries
        entries=$(get_uefi_entries)
        
        if [ $? -eq 0 ]; then
            echo "$entries"
            echo
            
            # Try to find USB automatically
            local usb_entry
            usb_entry=$(find_usb_entry "$entries")
            
            if [ $? -eq 0 ] && [ -n "$usb_entry" ]; then
                echo -n "Use Boot$usb_entry for next boot? (Y/n): "
                read -r response
                
                if [[ ! "$response" =~ ^[Nn]$ ]]; then
                    backup_boot_config
                    if set_uefi_next_boot "$usb_entry"; then
                        reboot_system
                        return 0
                    fi
                fi
            fi
            
            # Manual selection
            echo
            show_boot_entries "$entries"
            echo
            echo -n "Enter boot entry number (or 'q' to quit): "
            read -r manual_entry
            
            if [[ "$manual_entry" =~ ^[0-9A-Fa-f]{4}$ ]]; then
                backup_boot_config
                if set_uefi_next_boot "$manual_entry"; then
                    reboot_system
                fi
            elif [ "$manual_entry" != "q" ]; then
                error "Invalid boot entry format"
            fi
        fi
    else
        handle_grub_boot
        echo
        echo -n "Reboot now to enter BIOS setup? (y/N): "
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            backup_boot_config
            reboot_system
        fi
    fi
}

# Show help
show_help() {
    echo "Usage: sudo $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -i, --interactive    Interactive mode (default)"
    echo "  -a, --auto          Auto-detect and set USB boot"
    echo "  -e, --entry XXXX    Set specific boot entry (UEFI only)"
    echo "  -r, --reboot DELAY  Reboot after DELAY seconds (default: 10)"
    echo "  -b, --backup        Backup boot configuration only"
    echo "  --restore           Show restore instructions"
    echo
    echo "Examples:"
    echo "  sudo $0                    # Interactive mode"
    echo "  sudo $0 -a                 # Auto-detect USB and boot"
    echo "  sudo $0 -e 0001           # Set Boot0001 as next boot"
    echo "  sudo $0 -b                 # Backup boot config only"
}

# Main function
main() {
    echo "========================================"
    echo "     Windows Auto-Install Boot Setup"
    echo "========================================"
    echo
    
    # Check root privileges
    check_root
    
    # Parse arguments
    local auto_mode=false
    local boot_entry=""
    local reboot_delay=10
    local backup_only=false
    local show_restore=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--interactive)
                # Default mode, nothing to do
                shift
                ;;
            -a|--auto)
                auto_mode=true
                shift
                ;;
            -e|--entry)
                boot_entry="$2"
                shift 2
                ;;
            -r|--reboot)
                reboot_delay="$2"
                shift 2
                ;;
            -b|--backup)
                backup_only=true
                shift
                ;;
            --restore)
                show_restore=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Handle specific modes
    if [ "$show_restore" = true ]; then
        restore_boot_config
        exit 0
    fi
    
    if [ "$backup_only" = true ]; then
        backup_boot_config
        exit 0
    fi
    
    # Detect boot system
    local boot_system
    boot_system=$(detect_boot_system)
    
    if [ "$boot_system" != "uefi" ] && [ -n "$boot_entry" ]; then
        error "Boot entry selection only available on UEFI systems"
        exit 1
    fi
    
    # Auto mode
    if [ "$auto_mode" = true ]; then
        if [ "$boot_system" = "uefi" ]; then
            local entries
            entries=$(get_uefi_entries)
            
            if [ $? -eq 0 ]; then
                local usb_entry
                usb_entry=$(find_usb_entry "$entries")
                
                if [ $? -eq 0 ] && [ -n "$usb_entry" ]; then
                    backup_boot_config
                    if set_uefi_next_boot "$usb_entry"; then
                        reboot_system "$reboot_delay"
                        exit 0
                    fi
                fi
            fi
            
            error "Could not auto-detect USB boot entry"
            exit 1
        else
            error "Auto mode not supported on BIOS systems"
            exit 1
        fi
    fi
    
    # Specific boot entry
    if [ -n "$boot_entry" ]; then
        backup_boot_config
        if set_uefi_next_boot "$boot_entry"; then
            reboot_system "$reboot_delay"
        fi
        exit $?
    fi
    
    # Default to interactive mode
    interactive_mode
}

# Handle interruption
trap 'echo; error "Script interrupted"; exit 130' INT TERM

# Run main function
main "$@"