#!/bin/bash
# Copyright (c) 2025 vixnz. All rights reserved.
# Windows Auto-Install System - VM Testing Script
#
# This file is part of the Windows Auto-Install System.
# Unauthorized distribution is prohibited.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/vm-test.log"


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


log() { echo -e "${BLUE}[VM-TEST]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }

# Check QEMU dependencies
check_qemu_deps() {
    log "Checking QEMU dependencies..."
    
    local missing_deps=()
    
    if ! command -v qemu-system-x86_64 &> /dev/null; then
        missing_deps+=("qemu-system-x86")
    fi
    
    if ! command -v qemu-img &> /dev/null; then
        missing_deps+=("qemu-utils")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing QEMU dependencies: ${missing_deps[*]}"
        echo "Install with:"
        echo "  Ubuntu/Debian: sudo apt install qemu-system-x86 qemu-utils"
        echo "  Fedora: sudo dnf install qemu-system-x86 qemu-img"
        echo "  Arch: sudo pacman -S qemu-full"
        return 1
    fi
    
    success "QEMU dependencies found"
    return 0
}

# Create test VM disk
create_test_disk() {
    local disk_path="$1"
    local disk_size="${2:-20G}"
    
    log "Creating test VM disk: $disk_path ($disk_size)"
    
    if qemu-img create -f qcow2 "$disk_path" "$disk_size" &>> "$LOG_FILE"; then
        success "Test disk created: $disk_path"
    else
        error "Failed to create test disk"
        return 1
    fi
}

# Test ISO boot in QEMU
test_iso_boot() {
    local iso_path="$1"
    local test_duration="${2:-60}"  
    
    log "Testing ISO boot in QEMU..."
    log "ISO: $iso_path"
    log "Test duration: ${test_duration}s"
    
    # Create temporary disk for installation test
    local temp_disk="$PROJECT_DIR/temp/test_vm_disk.qcow2"
    mkdir -p "$(dirname "$temp_disk")"
    
    create_test_disk "$temp_disk" "20G" || return 1
    
    # QEMU command
    local qemu_cmd="qemu-system-x86_64 \
        -machine type=q35,accel=kvm:tcg \
        -cpu host \
        -m 2048 \
        -drive file=\"$temp_disk\",format=qcow2 \
        -cdrom \"$iso_path\" \
        -boot order=dc \
        -netdev user,id=net0 \
        -device virtio-net-pci,netdev=net0 \
        -display vnc=:1 \
        -daemonize \
        -pidfile \"$PROJECT_DIR/temp/qemu_test.pid\""
    
    log "Starting QEMU VM..."
    echo "QEMU Command: $qemu_cmd" >> "$LOG_FILE"
    
    # Start QEMU
    if eval "$qemu_cmd" &>> "$LOG_FILE"; then
        local qemu_pid=$(cat "$PROJECT_DIR/temp/qemu_test.pid" 2>/dev/null || echo "")
        
        if [ -n "$qemu_pid" ] && kill -0 "$qemu_pid" 2>/dev/null; then
            success "QEMU VM started (PID: $qemu_pid)"
            log "VM running on VNC display :1 (port 5901)"
            log "Connect with: vncviewer localhost:5901"
            
            log "Waiting ${test_duration}s for boot test..."
            sleep "$test_duration"
            
            if kill -0 "$qemu_pid" 2>/dev/null; then
                success "VM still running after ${test_duration}s - ISO appears bootable"
                
                # Stop VM
                log "Stopping test VM..."
                kill "$qemu_pid" 2>/dev/null || true
                sleep 3
                kill -9 "$qemu_pid" 2>/dev/null || true
                
                # Cleanup
                rm -f "$temp_disk" "$PROJECT_DIR/temp/qemu_test.pid"
                
                return 0
            else
                error "VM stopped unexpectedly - ISO may have boot issues"
                rm -f "$temp_disk" "$PROJECT_DIR/temp/qemu_test.pid"
                return 1
            fi
        else
            error "Failed to start QEMU VM"
            rm -f "$temp_disk" "$PROJECT_DIR/temp/qemu_test.pid"
            return 1
        fi
    else
        error "QEMU command failed"
        rm -f "$temp_disk" "$PROJECT_DIR/temp/qemu_test.pid"
        return 1
    fi
}

# Interactive VM test
interactive_vm_test() {
    local iso_path="$1"
    
    log "Starting interactive VM test..."
    
    local temp_disk="$PROJECT_DIR/temp/test_vm_disk.qcow2"
    mkdir -p "$(dirname "$temp_disk")"
    create_test_disk "$temp_disk" "20G" || return 1
    
    local qemu_cmd="qemu-system-x86_64 \
        -machine type=q35,accel=kvm:tcg \
        -cpu host \
        -m 2048 \
        -drive file=\"$temp_disk\",format=qcow2 \
        -cdrom \"$iso_path\" \
        -boot order=dc \
        -netdev user,id=net0 \
        -device virtio-net-pci,netdev=net0 \
        -display gtk"
    
    echo "========================================"
    echo "  Interactive VM Test"
    echo "========================================"
    echo "This will open a QEMU window with your ISO."
    echo "Watch for:"
    echo "  ✓ Windows installer starts"
    echo "  ✓ Unattended installation begins"
    echo "  ✓ No user prompts appear"
    echo
    echo "Close the VM window when satisfied."
    echo -n "Start interactive test? (y/N): "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log "Launching interactive QEMU session..."
        echo "QEMU Command: $qemu_cmd" >> "$LOG_FILE"
        
        if eval "$qemu_cmd" &>> "$LOG_FILE"; then
            success "Interactive VM test completed"
        else
            error "Interactive VM test failed"
            return 1
        fi
        
        rm -f "$temp_disk"
    else
        log "Interactive test skipped"
    fi
}

# Main function
main() {
    local iso_path="$1"
    local test_mode="${2:-auto}"  
    
    echo "========================================"
    echo "       QEMU ISO Testing"
    echo "========================================"
    
    
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "VM Test Session: $(date)" > "$LOG_FILE"
    
    # Validate ISO
    if [ ! -f "$iso_path" ]; then
        error "ISO file not found: $iso_path"
        exit 1
    fi
    
    log "Testing ISO: $iso_path"
    
    # Check dependencies
    check_qemu_deps || exit 1
    
    case "$test_mode" in
        "auto")
            log "Running automated boot test..."
            if test_iso_boot "$iso_path" 120; then
                success "Automated ISO test PASSED"
                exit 0
            else
                error "Automated ISO test FAILED"
                exit 1
            fi
            ;;
        "interactive")
            interactive_vm_test "$iso_path"
            ;;
        "both")
            log "Running both automated and interactive tests..."
            if test_iso_boot "$iso_path" 60; then
                success "Automated test PASSED"
                interactive_vm_test "$iso_path"
            else
                error "Automated test FAILED - skipping interactive test"
                exit 1
            fi
            ;;
        *)
            error "Invalid test mode: $test_mode"
            echo "Valid modes: auto, interactive, both"
            exit 1
            ;;
    esac
}


show_help() {
    echo "QEMU VM Testing for Windows Auto-Install"
    echo
    echo "Usage: $0 <iso_path> [test_mode]"
    echo
    echo "Arguments:"
    echo "  iso_path    Path to Windows ISO file"
    echo "  test_mode   Test mode: auto, interactive, both (default: auto)"
    echo
    echo "Examples:"
    echo "  $0 Windows-Unattended.iso"
    echo "  $0 Windows-Unattended.iso interactive"
    echo "  $0 Windows-Unattended.iso both"
}

# Handle arguments
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

main "$@"