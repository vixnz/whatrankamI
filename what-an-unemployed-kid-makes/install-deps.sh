#!/bin/bash
# Copyright (c) 2025 vixnz. All rights reserved.
# Windows Auto-Install System - Dependencies Installation Script
#
# This file is part of the Windows Auto-Install System.
# Unauthorized distribution is prohibited.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Install dependencies based on distribution
install_deps() {
    local distro
    distro=$(detect_distro)
    
    log "Detected distribution: $distro"
    
    case "$distro" in
        "ubuntu"|"debian"|"pop"|"linuxmint")
            log "Installing dependencies for Debian/Ubuntu..."
            apt update
            apt install -y p7zip-full genisoimage wimtools efibootmgr parted dosfstools coreutils util-linux
            
            # Optional: Install Ventoy if available
            if apt list ventoy 2>/dev/null | grep -q ventoy; then
                apt install -y ventoy
                success "Ventoy installed"
            else
                warning "Ventoy not available in repositories - install manually if needed"
            fi
            ;;
            
        "fedora"|"centos"|"rhel"|"rocky"|"almalinux")
            log "Installing dependencies for Red Hat/Fedora..."
            if command -v dnf &>/dev/null; then
                dnf install -y p7zip genisoimage wimlib efibootmgr parted dosfstools coreutils util-linux
            else
                yum install -y p7zip genisoimage wimlib efibootmgr parted dosfstools coreutils util-linux
            fi
            ;;
            
        "arch"|"manjaro"|"endeavouros")
            log "Installing dependencies for Arch Linux..."
            pacman -Sy --noconfirm p7zip cdrkit wimlib efibootmgr parted dosfstools coreutils util-linux
            ;;
            
        "opensuse"|"opensuse-leap"|"opensuse-tumbleweed")
            log "Installing dependencies for openSUSE..."
            zypper install -y p7zip genisoimage wimlib efibootmgr parted dosfstools coreutils util-linux
            ;;
            
        *)
            error "Unsupported distribution: $distro"
            echo "Please install these packages manually:"
            echo "- p7zip-full (or p7zip)"
            echo "- genisoimage (or cdrkit)"  
            echo "- wimtools (or wimlib)"
            echo "- efibootmgr"
            echo "- parted"
            echo "- dosfstools"
            echo "- coreutils"
            echo "- util-linux"
            return 1
            ;;
    esac
    
    success "Core dependencies installed successfully"
}

# Verify installation
verify_deps() {
    log "Verifying installed dependencies..."
    
    local missing=()
    
    command -v 7z >/dev/null || missing+=("7z")
    command -v genisoimage >/dev/null || missing+=("genisoimage") 
    command -v wimlib-imagex >/dev/null || missing+=("wimlib-imagex")
    command -v efibootmgr >/dev/null || missing+=("efibootmgr")
    command -v parted >/dev/null || missing+=("parted")
    command -v mkfs.fat >/dev/null || missing+=("mkfs.fat")
    
    if [ ${#missing[@]} -eq 0 ]; then
        success "All required dependencies are installed"
        return 0
    else
        error "Missing dependencies: ${missing[*]}"
        return 1
    fi
}

# Main function
main() {
    echo "========================================"
    echo "  Windows Auto-Install Dependencies"
    echo "========================================"
    echo
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Install dependencies
    install_deps
    echo
    
    # Verify installation
    verify_deps
    echo
    
    success "Setup complete! You can now run the Windows Auto-Install system."
    echo
    echo "Next steps:"
    echo "1. Get a Windows ISO file"
    echo "2. Run: sudo ./auto-install.sh /path/to/Windows.iso"
    echo "========================================"
}

main "$@"