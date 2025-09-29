#!/bin/bash
# Copyright (c) 2025 vixnz. All rights reserved.
# Windows Auto-Install System - ISO Creation Script
#
# This file is part of the Windows Auto-Install System.
# Unauthorized distribution is prohibited.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/config"
TEMP_DIR="$PROJECT_DIR/temp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
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

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v 7z &> /dev/null; then
        missing_deps+=("p7zip-full")
    fi
    
    if ! command -v genisoimage &> /dev/null; then
        missing_deps+=("genisoimage")
    fi
    
    if ! command -v wimlib-imagex &> /dev/null; then
        missing_deps+=("wimtools")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing dependencies: ${missing_deps[*]}"
        echo "Install with: sudo apt install ${missing_deps[*]}"
        exit 1
    fi
    
    success "All dependencies are installed"
}

# Extract Windows ISO
extract_iso() {
    local iso_path="$1"
    local extract_dir="$TEMP_DIR/windows_extracted"
    
    log "Extracting Windows ISO: $iso_path"
    
    # Clean previous extraction
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"
    
    # Extract ISO using 7zip
    if ! 7z x "$iso_path" -o"$extract_dir" &> /dev/null; then
        error "Failed to extract ISO"
        exit 1
    fi
    
    success "ISO extracted to: $extract_dir"
    echo "$extract_dir"
}

# Inject autounattend.xml
inject_autounattend() {
    local extract_dir="$1"
    local autounattend_path="$CONFIG_DIR/autounattend.xml"
    
    log "Injecting autounattend.xml..."
    
    if [ ! -f "$autounattend_path" ]; then
        error "autounattend.xml not found at: $autounattend_path"
        exit 1
    fi
    
    # Copy autounattend.xml to root of extracted ISO
    cp "$autounattend_path" "$extract_dir/"
    
    # Also copy to sources directory (alternative location)
    mkdir -p "$extract_dir/sources"
    cp "$autounattend_path" "$extract_dir/sources/"
    
    success "autounattend.xml injected successfully"
}

# Create new ISO
create_iso() {
    local extract_dir="$1"
    local output_iso="$2"
    
    log "Creating new ISO: $output_iso"
    
    # Remove existing output ISO
    rm -f "$output_iso"
    
    # Create bootable ISO
    if genisoimage \
        -b "boot/etfsboot.com" \
        -no-emul-boot \
        -boot-load-size 8 \
        -iso-level 2 \
        -udf \
        -joliet \
        -D \
        -N \
        -relaxed-filenames \
        -o "$output_iso" \
        "$extract_dir" &> /dev/null; then
        success "ISO created successfully: $output_iso"
    else
        error "Failed to create ISO"
        exit 1
    fi
}

# Verify autounattend.xml injection
verify_autounattend_injection() {
    local iso_path="$1"
    
    log "Verifying autounattend.xml injection..."
    
    # Check if autounattend.xml exists in ISO root
    if 7z l "$iso_path" 2>/dev/null | grep -q "autounattend.xml$"; then
        success "autounattend.xml found in ISO root"
    else
        error "autounattend.xml NOT found in ISO root"
        return 1
    fi
    
    # Check if autounattend.xml exists in sources directory
    if 7z l "$iso_path" 2>/dev/null | grep -q "sources.*autounattend.xml"; then
        success "autounattend.xml found in sources directory"
    else
        warning "autounattend.xml not found in sources directory (may still work)"
    fi
    
    # Verify file content by extracting and checking
    local temp_check="$TEMP_DIR/verify_autounattend.xml"
    if 7z e "$iso_path" "autounattend.xml" -o"$TEMP_DIR" &>/dev/null; then
        if grep -q "Microsoft-Windows-Setup" "$temp_check"; then
            success "autounattend.xml content verified"
            rm -f "$temp_check"
        else
            error "autounattend.xml appears corrupted"
            rm -f "$temp_check"
            return 1
        fi
    else
        error "Could not extract autounattend.xml for verification"
        return 1
    fi
    
    return 0
}

# Verify ISO integrity
verify_iso() {
    local iso_path="$1"
    
    log "Verifying ISO integrity..."
    
    if [ -f "$iso_path" ] && [ -s "$iso_path" ]; then
        local size=$(du -h "$iso_path" | cut -f1)
        success "ISO verified - Size: $size"
        return 0
    else
        error "ISO verification failed"
        return 1
    fi
}

# Main function
main() {
    echo "========================================"
    echo "  Windows Auto-Install ISO Builder"
    echo "========================================"
    echo
    
    # Check if ISO path is provided
    if [ $# -eq 0 ]; then
        error "Usage: $0 <path_to_windows_iso> [output_name]"
        echo "Example: $0 /path/to/Windows11.iso"
        echo "         $0 /path/to/Windows11.iso Windows11-Auto.iso"
        exit 1
    fi
    
    local input_iso="$1"
    local output_name="${2:-Windows-Unattended.iso}"
    local output_iso="$PROJECT_DIR/$output_name"
    
    # Validate input ISO
    if [ ! -f "$input_iso" ]; then
        error "Input ISO not found: $input_iso"
        exit 1
    fi
    
    log "Input ISO: $input_iso"
    log "Output ISO: $output_iso"
    echo
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Check dependencies
    check_dependencies
    echo
    
    # Extract ISO
    local extract_dir
    extract_dir=$(extract_iso "$input_iso")
    echo
    
    # Inject autounattend.xml
    inject_autounattend "$extract_dir"
    echo
    
    # Create new ISO
    create_iso "$extract_dir" "$output_iso"
    echo
    
    # Verify ISO
    verify_iso "$output_iso"
    echo
    
    # Verify autounattend.xml injection
    verify_autounattend_injection "$output_iso"
    echo
    
    # Cleanup
    log "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR/windows_extracted"
    
    echo "========================================"
    success "Unattended Windows ISO created successfully!"
    echo "Location: $output_iso"
    echo
    echo "Next steps:"
    echo "1. Create bootable USB: ./create-usb.sh $output_iso"
    echo "2. Run automated installation: ./auto-install.sh"
    echo "========================================"
}

# Handle interruption
trap 'echo; error "Script interrupted"; rm -rf "$TEMP_DIR/windows_extracted"; exit 130' INT TERM

# Run main function
main "$@"