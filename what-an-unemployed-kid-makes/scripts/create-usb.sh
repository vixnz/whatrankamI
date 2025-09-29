#!/bin/bash
# Copyright (c) 2025 vixnz. All rights reserved.
# Windows Auto-Install System - USB Creation Script
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
        echo "Example: sudo $0 /path/to/Windows-Unattended.iso /dev/sdX"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v dd &> /dev/null; then
        missing_deps+=("coreutils")
    fi
    
    if ! command -v parted &> /dev/null; then
        missing_deps+=("parted")
    fi
    
    if ! command -v mkfs.fat &> /dev/null; then
        missing_deps+=("dosfstools")
    fi
    
    if ! command -v ventoy &> /dev/null && ! command -v 7z &> /dev/null; then
        warning "Neither Ventoy nor 7z found. Installing basic dependencies..."
        missing_deps+=("p7zip-full")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing dependencies: ${missing_deps[*]}"
        echo "Install with: apt install ${missing_deps[*]}"
        exit 1
    fi
    
    success "Dependencies check passed"
}

# List available USB devices
list_usb_devices() {
    log "Available USB devices:"
    echo
    
    # Find removable devices
    local usb_devices=()
    for device in /sys/block/sd*; do
        if [ -e "$device/removable" ] && [ "$(cat "$device/removable")" = "1" ]; then
            local dev_name=$(basename "$device")
            local dev_path="/dev/$dev_name"
            
            if [ -e "$dev_path" ]; then
                local size=$(lsblk -n -o SIZE "$dev_path" 2>/dev/null || echo "Unknown")
                local model=$(lsblk -n -o MODEL "$dev_path" 2>/dev/null || echo "Unknown")
                
                echo -e "  ${YELLOW}$dev_path${NC} - Size: $size - Model: $model"
                usb_devices+=("$dev_path")
            fi
        fi
    done
    
    if [ ${#usb_devices[@]} -eq 0 ]; then
        warning "No USB devices detected"
        echo "Make sure your USB drive is connected and try again"
        return 1
    fi
    
    echo
    return 0
}

# Verify USB device
verify_usb_device() {
    local usb_device="$1"
    
    log "Verifying USB device: $usb_device"
    
    if [ ! -e "$usb_device" ]; then
        error "Device $usb_device does not exist"
        return 1
    fi
    
    if [ ! -b "$usb_device" ]; then
        error "$usb_device is not a block device"
        return 1
    fi
    
    # Check if it's removable
    local device_name=$(basename "$usb_device")
    local sys_path="/sys/block/$device_name"
    
    if [ -e "$sys_path/removable" ] && [ "$(cat "$sys_path/removable")" != "1" ]; then
        warning "$usb_device might not be a removable device"
        echo -n "Continue anyway? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Operation cancelled"
            exit 1
        fi
    fi
    
    success "USB device verified"
    return 0
}

# Check USB device size
check_usb_size() {
    local usb_device="$1"
    local iso_path="$2"
    
    log "Checking USB device capacity..."
    
    local usb_size_bytes=$(blockdev --getsize64 "$usb_device")
    local usb_size_mb=$((usb_size_bytes / 1024 / 1024))
    local iso_size_bytes=$(stat -c%s "$iso_path")
    local iso_size_mb=$((iso_size_bytes / 1024 / 1024))
    
    info "USB Size: ${usb_size_mb}MB"
    info "ISO Size: ${iso_size_mb}MB"
    
    if [ "$usb_size_mb" -lt "$iso_size_mb" ]; then
        error "USB device too small. Need at least ${iso_size_mb}MB"
        return 1
    fi
    
    if [ "$usb_size_mb" -lt 8000 ]; then
        warning "USB device is smaller than 8GB. Windows installation might fail."
    fi
    
    success "USB device size check passed"
    return 0
}

# Unmount USB partitions
unmount_usb() {
    local usb_device="$1"
    
    log "Unmounting USB partitions..."
    
    # Find all partitions on the device
    local partitions=$(lsblk -ln -o NAME "$usb_device" | tail -n +2 | sed "s|^|/dev/|")
    
    for partition in $partitions; do
        if mountpoint -q "$partition" 2>/dev/null; then
            log "Unmounting $partition..."
            umount "$partition" 2>/dev/null || true
        fi
    done
    
    success "USB partitions unmounted"
}

# Create bootable USB using dd method
create_usb_dd() {
    local iso_path="$1"
    local usb_device="$2"
    
    log "Creating bootable USB using dd method..."
    warning "This will ERASE ALL DATA on $usb_device"
    
    echo -n "Continue? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 1
    fi
    
    # Unmount the device
    unmount_usb "$usb_device"
    
    # Write ISO to USB
    log "Writing ISO to USB device... (this may take several minutes)"
    if dd if="$iso_path" of="$usb_device" bs=4M status=progress oflag=sync; then
        success "ISO written to USB successfully"
    else
        error "Failed to write ISO to USB"
        return 1
    fi
    
    
    log "Syncing filesystem..."
    sync
    
    success "Bootable USB created successfully using dd method"
    
    # Verify USB creation
    if verify_usb_creation "$usb_device" "dd"; then
        success "DD USB verification passed"
    else
        error "DD USB verification failed"
        return 1
    fi
}

# Verify USB creation
verify_usb_creation() {
    local usb_device="$1"
    local method="$2"
    
    log "Verifying USB creation..."
    
    
    sleep 3
    partprobe "$usb_device" 2>/dev/null || true
    sleep 2
    
    
    local main_partition=""
    if [ "$method" = "ventoy" ]; then
        # Ventoy method - find the first partition
        main_partition="${usb_device}1"
        [ ! -e "$main_partition" ] && main_partition="${usb_device}p1"
    else
        # DD method - find the first partition
        main_partition="${usb_device}1"
        [ ! -e "$main_partition" ] && main_partition="${usb_device}p1"
    fi
    
    if [ ! -e "$main_partition" ]; then
        error "Could not find USB partition for verification"
        return 1
    fi
    
    # Create temporary mount point
    local mount_point="/tmp/usb_verify_$$"
    mkdir -p "$mount_point"
    
    
    if mount "$main_partition" "$mount_point" 2>/dev/null; then
        log "USB partition mounted successfully"
        
        # Basic checks
        local verification_passed=true
        
        if [ "$method" = "ventoy" ]; then
            # For Ventoy, check for ISO files
            if find "$mount_point" -name "*.iso" -type f | head -1 | grep -q .; then
                success "ISO file found on Ventoy USB"
            else
                error "No ISO file found on Ventoy USB"
                verification_passed=false
            fi
            
            # Check for Ventoy system files
            if [ -d "$mount_point/ventoy" ] || [ -f "$mount_point/VENTOY/ventoy.json" ]; then
                success "Ventoy system files found"
            else
                warning "Ventoy system files not found (may still work)"
            fi
        else
            # For DD method, check for Windows boot files
            if [ -f "$mount_point/bootmgr" ] || [ -f "$mount_point/setup.exe" ]; then
                success "Windows boot files found"
            else
                error "Windows boot files not found"
                verification_passed=false
            fi

            # Check for sources directory
            if [ -d "$mount_point/sources" ]; then
                success "Windows sources directory found"
            else
                error "Windows sources directory missing"
                verification_passed=false
            fi
        fi
        
        # Cleanup
        umount "$mount_point"
        rmdir "$mount_point"
        
        if [ "$verification_passed" = true ]; then
            success "USB verification PASSED"
            return 0
        else
            error "USB verification FAILED"
            return 1
        fi
    else
        error "Could not mount USB partition for verification"
        rmdir "$mount_point" 2>/dev/null || true
        return 1
    fi
}

# Create bootable USB using Ventoy
create_usb_ventoy() {
    local iso_path="$1"
    local usb_device="$2"
    
    log "Creating bootable USB using Ventoy..."
    
    if ! command -v ventoy &> /dev/null; then
        error "Ventoy not found. Install with: sudo apt install ventoy"
        echo "Falling back to dd method..."
        create_usb_dd "$iso_path" "$usb_device"
        return $?
    fi
    
    warning "This will ERASE ALL DATA on $usb_device and install Ventoy"
    echo -n "Continue? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 1
    fi
    
    # Install Ventoy
    log "Installing Ventoy on $usb_device..."
    if ventoy -i "$usb_device" -y; then
        success "Ventoy installed successfully"
    else
        error "Ventoy installation failed"
        return 1
    fi
    
    # Wait for system to recognize new partitions
    sleep 3
    partprobe "$usb_device"
    sleep 2
    
    # Find Ventoy partition
    local ventoy_partition="${usb_device}1"
    if [ ! -e "$ventoy_partition" ]; then
        ventoy_partition="${usb_device}p1"
        if [ ! -e "$ventoy_partition" ]; then
            error "Could not find Ventoy partition"
            return 1
        fi
    fi
    
    # Mount Ventoy partition
    local mount_point="/tmp/ventoy_mount_$$"
    mkdir -p "$mount_point"
    
    if mount "$ventoy_partition" "$mount_point"; then
        log "Copying ISO to Ventoy partition..."
        cp "$iso_path" "$mount_point/"
        sync
        umount "$mount_point"
        rmdir "$mount_point"
        success "ISO copied to Ventoy USB successfully"
    else
        error "Failed to mount Ventoy partition"
        rmdir "$mount_point" 2>/dev/null || true
        return 1
    fi
    
    success "Bootable USB created successfully using Ventoy"
    
    
    if verify_usb_creation "$usb_device" "ventoy"; then
        success "Ventoy USB verification passed"
    else
        error "Ventoy USB verification failed"
        return 1
    fi
}

# Show completion info
show_completion_info() {
    local usb_device="$1"
    local method="$2"
    
    echo
    echo "========================================"
    success "Bootable USB created successfully!"
    echo "========================================"
    echo "Device: $usb_device"
    echo "Method: $method"
    echo
    echo "Next steps:"
    echo "1. Boot from USB device"
    echo "2. Windows will install automatically"
    echo "3. Default credentials:"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo
    echo "Boot settings:"
    echo "- Enable UEFI boot mode"
    echo "- Disable Secure Boot (if needed)"
    echo "- Set USB as first boot device"
    echo "========================================"
}

# Main function
main() {
    echo "========================================"
    echo "  Windows Auto-Install USB Creator"
    echo "========================================"
    echo
    
    # Check arguments
    if [ $# -lt 1 ]; then
        error "Usage: sudo $0 <iso_path> [usb_device] [method]"
        echo
        echo "Arguments:"
        echo "  iso_path    - Path to Windows ISO file"
        echo "  usb_device  - USB device (e.g., /dev/sdb) - will prompt if not provided"
        echo "  method      - 'ventoy' or 'dd' (default: ventoy)"
        echo
        echo "Examples:"
        echo "  sudo $0 Windows-Unattended.iso"
        echo "  sudo $0 Windows-Unattended.iso /dev/sdb"
        echo "  sudo $0 Windows-Unattended.iso /dev/sdb dd"
        exit 1
    fi
    
    local iso_path="$1"
    local usb_device="${2:-}"
    local method="${3:-ventoy}"
    
    # Validate ISO path
    if [ ! -f "$iso_path" ]; then
        error "ISO file not found: $iso_path"
        exit 1
    fi
    
    log "ISO file: $iso_path"
    
    # Check if running as root
    check_root
    
    # Check dependencies
    check_dependencies
    echo
    
    # List USB devices if not specified
    if [ -z "$usb_device" ]; then
        if list_usb_devices; then
            echo -n "Enter USB device path (e.g., /dev/sdb): "
            read -r usb_device
        else
            exit 1
        fi
    fi
    
    
    if [ -z "$usb_device" ]; then
        error "USB device not specified"
        exit 1
    fi
    
    log "USB device: $usb_device"
    log "Method: $method"
    echo
    
    # Verify USB device
    verify_usb_device "$usb_device"
    
    # Check USB size
    check_usb_size "$usb_device" "$iso_path"
    echo
    
    # Create USB based on method
    case "$method" in
        "ventoy")
            create_usb_ventoy "$iso_path" "$usb_device"
            ;;
        "dd")
            create_usb_dd "$iso_path" "$usb_device"
            ;;
        *)
            error "Unknown method: $method. Use 'ventoy' or 'dd'"
            exit 1
            ;;
    esac
    
    # Show completion info
    show_completion_info "$usb_device" "$method"
}


trap 'echo; error "Script interrupted"; exit 130' INT TERM


main "$@"