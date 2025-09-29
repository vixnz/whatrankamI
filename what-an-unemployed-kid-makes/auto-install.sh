#!/bin/bash
# Copyright (c) 2025 vixnz. All rights reserved.
# Windows Auto-Install System - Main Automation Script
#
# This file is part of the Windows Auto-Install System.
# Unauthorized distribution is prohibited.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

init_logging() {
init_logging() {
    local log_dir="$(dirname "$LOG_FILE")"
    mkdir -p "$log_dir"
    
    echo "===============================    local input_iso="$1"
    
    show_workflow
    
    warning "This will modify USB devices and reboot your system!"===" >> "$LOG_FILE"
    echo "Windows Auto-Install Session Started: $(date)" >> "$LOG_FILE"
    echo "Command: $0 $*" >> "$LOG_FILE"
    echo "=========================================" >> "$LOG_FILE"
}
log() {
    local msg="${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo -e "$msg"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOG_FILE"
}

error() {
    local msg="${RED}[ERROR]${NC} $1"
    echo -e "$msg" >&2
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

success() {
    local msg="${GREEN}[SUCCESS]${NC} $1"
    echo -e "$msg"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$LOG_FILE"
}

warning() {
    local msg="${YELLOW}[WARNING]${NC} $1"
    echo -e "$msg"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

info() {
    local msg="${PURPLE}[INFO]${NC} $1"
    echo -e "$msg"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOG_FILE"
}

banner() {
    local msg="${CYAN}$1${NC}"
    echo -e "$msg"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] BANNER: $1" >> "$LOG_FILE"
}
execute_command() {
    local description="$1"
    local command="$2"
    
    if [ "$DRY_RUN" = true ]; then
        warning "[DRY-RUN] Would execute: $description"
        info "[DRY-RUN] Command: $command"
        return 0
    else
        log "Executing: $description"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] EXEC: $command" >> "$LOG_FILE"
        eval "$command"
        local exit_code=$?
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] EXIT_CODE: $exit_code" >> "$LOG_FILE"
        return $exit_code
    fi
}

CONFIG_FILE="$PROJECT_DIR/config/settings.conf"
STATE_FILE="$PROJECT_DIR/.install_state"
LOG_FILE="$PROJECT_DIR/logs/autoinstall.log"

DRY_RUN=false
VM_TEST=false
VERIFY_ALL=false

DEFAULT_USB_METHOD="ventoy"
DEFAULT_REBOOT_DELAY=10
DEFAULT_AUTO_REBOOT=true
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << EOF
USB_METHOD=$DEFAULT_USB_METHOD
REBOOT_DELAY=$DEFAULT_REBOOT_DELAY
AUTO_REBOOT=$DEFAULT_AUTO_REBOOT
WINDOWS_EDITION=Professional
WINDOWS_LANGUAGE=en-US
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
COMPUTER_NAME=Windows-Auto
AUTO_PARTITION=true
SKIP_OOBE=true
DISABLE_DEFENDER=false
INSTALL_UPDATES=true
EOF
        success "Created default configuration: $CONFIG_FILE"
        warning "Please review and customize the settings in $CONFIG_FILE"
    fi
    
    source "$CONFIG_FILE"
}
save_state() {
    local state="$1"
    local info="${2:-}"
    
    echo "STATE=$state" > "$STATE_FILE"
    echo "TIMESTAMP=$(date)" >> "$STATE_FILE"
    [ -n "$info" ] && echo "INFO=$info" >> "$STATE_FILE"
}

load_state() {
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
        echo "$STATE"
    else
        echo "init"
    fi
}

clear_state() {
    rm -f "$STATE_FILE"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root for USB creation and boot setup"
        echo "Run with: sudo $0"
        exit 1
    fi
}

validate_iso() {
    local iso_path="$1"
    
    log "Validating Windows ISO..."
    
    if [ ! -f "$iso_path" ]; then
        error "ISO file not found: $iso_path"
        return 1
    fi
    
    local size_bytes=$(stat -c%s "$iso_path")
    local size_mb=$((size_bytes / 1024 / 1024))
    
    if [ "$size_mb" -lt 3000 ]; then
        warning "ISO file seems small ($size_mb MB). Are you sure this is a Windows ISO?"
        echo -n "Continue anyway? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    if command -v 7z &> /dev/null; then
        local files
        files=$(7z l "$iso_path" 2>/dev/null | grep -i "setup.exe\|sources/install" || echo "")
        
        if [ -z "$files" ]; then
            warning "This doesn't appear to be a Windows ISO (no setup.exe or sources/install found)"
            echo -n "Continue anyway? (y/N): "
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                return 1
            fi
        fi
    fi
    
    success "ISO validation passed"
    return 0
}

show_workflow() {
    banner "=========================================="
    banner "    Windows Auto-Install Workflow"
    banner "=========================================="
    echo
    echo "This script will:"
    echo "  1. ✓ Validate Windows ISO file"
    echo "  2. ✓ Create unattended installation ISO"
    echo "  3. ✓ Create bootable USB drive"
    echo "  4. ✓ Configure boot priority"
    echo "  5. ✓ Automatically reboot to Windows installer"
    echo
    echo "After reboot, Windows will:"
    echo "  • Install automatically (no user input)"
    echo "  • Create admin account (username: $ADMIN_USERNAME)"
    echo "  • Skip OOBE (Out of Box Experience)"
    echo "  • Boot to desktop ready for use"
    echo
    echo "Installation time: ~15-45 minutes"
    echo
}

step_prepare_iso() {
    local input_iso="$1"
    local output_iso="$PROJECT_DIR/Windows-Unattended.iso"
    
    banner "Step 1: Preparing Unattended Installation ISO"
    echo
    
    if [ -f "$output_iso" ]; then
        warning "Unattended ISO already exists: $output_iso"
        echo -n "Recreate it? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            success "Using existing unattended ISO"
            save_state "iso_ready" "$output_iso"
            return 0
        fi
    fi
    
    log "Creating unattended installation ISO..."
    if [ "$DRY_RUN" = true ]; then
        execute_command "Create unattended ISO" "$SCRIPT_DIR/create-iso.sh '$input_iso' 'Windows-Unattended.iso'"
        save_state "iso_ready" "$output_iso"
        success "[DRY-RUN] Unattended ISO would be created: $output_iso"
    else
        if "$SCRIPT_DIR/create-iso.sh" "$input_iso" "Windows-Unattended.iso"; then
            save_state "iso_ready" "$output_iso"
            success "Unattended ISO created: $output_iso"
            
            if [ "$VM_TEST" = true ]; then
                log "Running VM test on created ISO..."
                if "$SCRIPT_DIR/test-vm.sh" "$output_iso" "auto"; then
                    success "VM test passed - ISO boots correctly"
                else
                    error "VM test failed - ISO may have issues"
                    echo -n "Continue anyway? (y/N): "
                    read -r response
                    if [[ ! "$response" =~ ^[Yy]$ ]]; then
                        return 1
                    fi
                fi
            fi
        else
            error "Failed to create unattended ISO"
            return 1
        fi
    fi
}

step_create_usb() {
    local iso_path="$1"
    
    banner "Step 2: Creating Bootable USB Drive"
    echo
    
    log "Scanning for USB devices..."
    
    local usb_devices=()
    for device in /sys/block/sd*; do
        if [ -e "$device/removable" ] && [ "$(cat "$device/removable")" = "1" ]; then
            local dev_name=$(basename "$device")
            local dev_path="/dev/$dev_name"
            if [ -e "$dev_path" ]; then
                usb_devices+=("$dev_path")
            fi
        fi
    done
    
    if [ ${#usb_devices[@]} -eq 0 ]; then
        error "No USB devices detected"
        echo "Please connect a USB drive (8GB+ recommended) and try again"
        return 1
    fi
    
    log "Creating bootable USB..."
    if [ "$DRY_RUN" = true ]; then
        execute_command "Create bootable USB" "$SCRIPT_DIR/create-usb.sh '$iso_path' '' '$USB_METHOD'"
        save_state "usb_ready"
        success "[DRY-RUN] Bootable USB would be created"
    else
        if "$SCRIPT_DIR/create-usb.sh" "$iso_path" "" "$USB_METHOD"; then
            save_state "usb_ready"
            success "Bootable USB created successfully"
        else
            error "Failed to create bootable USB"
            return 1
        fi
    fi
}

step_configure_boot() {
    banner "Step 3: Configuring Boot Priority"
    echo
    
    log "Setting up boot configuration..."
    if [ "$DRY_RUN" = true ]; then
        execute_command "Configure boot priority" "$SCRIPT_DIR/boot-setup.sh --auto"
        save_state "boot_configured"
        success "[DRY-RUN] Boot configuration would be completed"
    else
        if "$SCRIPT_DIR/boot-setup.sh" --auto; then
            save_state "boot_configured"
            success "Boot configuration completed"
        else
            warning "Automatic boot setup failed"
            echo "Manual boot setup required:"
            echo "1. Restart and enter BIOS/UEFI setup"
            echo "2. Set USB device as first boot option"
            echo "3. Save and exit"
            echo
            echo -n "Continue with manual reboot? (y/N): "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                save_state "manual_boot"
                return 0
            else
                return 1
            fi
        fi
    fi
}

step_final_reboot() {
    banner "Step 4: Starting Windows Installation"
    echo
    
    success "All preparation steps completed!"
    echo
    echo "Windows installation will now begin automatically."
    echo "The system will:"
    echo "  • Reboot from USB drive"
    echo "  • Install Windows unattended"
    echo "  • Create user account: $ADMIN_USERNAME"
    echo "  • Boot to desktop (15-45 minutes)"
    echo
    
    if [ "$DRY_RUN" = true ]; then
        success "[DRY-RUN] System would reboot to Windows installation"
        save_state "ready_to_reboot"
    elif [ "$AUTO_REBOOT" = true ]; then
        warning "System will reboot in $REBOOT_DELAY seconds..."
        echo "Press Ctrl+C to cancel"
        
        for ((i=REBOOT_DELAY; i>=1; i--)); do
            echo -ne "\rRebooting in $i seconds... "
            sleep 1
        done
        
        echo
        log "Rebooting system..."
        save_state "installing"
        execute_command "Reboot system" "reboot"
    else
        echo "Automatic reboot disabled in configuration."
        echo "Please reboot manually to start Windows installation."
        save_state "ready_to_reboot"
    fi
}

resume_workflow() {
    local current_state
    current_state=$(load_state)
    
    case "$current_state" in
        "init")
            return 1  # Start from beginning
            ;;
        "iso_ready")
            log "Resuming from: ISO preparation completed"
            return 2  # Skip to USB creation
            ;;
        "usb_ready")
            log "Resuming from: USB creation completed"
            return 3  # Skip to boot configuration
            ;;
        "boot_configured"|"manual_boot")
            log "Resuming from: Boot configuration completed"
            return 4  # Skip to final reboot
            ;;
        "ready_to_reboot")
            log "System ready to reboot for Windows installation"
            echo -n "Reboot now? (y/N): "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                step_final_reboot
            fi
            return 0
            ;;
        "installing")
            success "Windows installation in progress or completed"
            echo "If you're seeing this message, the installation may be complete."
            echo "Check your Windows installation and run: sudo $0 --reset"
            return 0
            ;;
        *)
            warning "Unknown state: $current_state"
            return 1
            ;;
    esac
}

run_full_workflow() {
    local input_iso="$1"
    
    # Show workflow overview
    show_workflow
    
    # Confirm before proceeding
    warning "This will modify USB devices and reboot your system!"
    echo -n "Continue with automated Windows installation? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 1
    fi
    
    echo
    
    local resume_step
    if resume_workflow; then
        return $?
    else
        resume_step=$?
    fi
    
    case "$resume_step" in
        1|2)
            step_prepare_iso "$input_iso" || return 1
            ;;&
        2|3)
            local iso_path="$PROJECT_DIR/Windows-Unattended.iso"
            step_create_usb "$iso_path" || return 1
            ;;&
        3|4)
            step_configure_boot || return 1
            ;;&
        4)
            step_final_reboot
            ;;
    esac
    
    return 0
}

show_status() {
    banner "=========================================="
    banner "    Installation Status"
    banner "=========================================="
    
    local current_state
    current_state=$(load_state)
    
    echo "Current state: $current_state"
    
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
        echo "Last updated: $TIMESTAMP"
        [ -n "${INFO:-}" ] && echo "Additional info: $INFO"
    fi
    
    echo
    echo "Project files:"
    echo "  Configuration: $CONFIG_FILE"
    echo "  Unattended ISO: $PROJECT_DIR/Windows-Unattended.iso"
    echo "  Backup folder: $PROJECT_DIR/backup/"
    
    echo
    echo "Available commands:"
    echo "  sudo $0 <iso_file>     # Run full installation"
    echo "  sudo $0 --status       # Show current status"
    echo "  sudo $0 --reset        # Reset installation state"
    echo "  sudo $0 --config       # Edit configuration"
}

show_help() {
    echo "Windows Auto-Install Master Script"
    echo
    echo "Usage: sudo $0 [OPTIONS] [ISO_FILE]"
    echo
    echo "Arguments:"
    echo "  ISO_FILE              Path to Windows ISO file"
    echo
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -s, --status         Show installation status"
    echo "  -r, --reset          Reset installation state"
    echo "  -c, --config         Edit configuration file"
    echo "  --dry-run            Show what would be done without executing"
    echo "  --vm-test            Test ISO in QEMU before USB creation"
    echo "  --verify-all         Enable comprehensive verification at each step"
    echo "  --step1 ISO_FILE     Run step 1 only (create unattended ISO)"
    echo "  --step2 ISO_FILE     Run step 2 only (create USB)"
    echo "  --step3              Run step 3 only (configure boot)"
    echo "  --step4              Run step 4 only (reboot)"
    echo
    echo "Safety Options:"
    echo "  --dry-run            Preview all operations without execution"
    echo "  --vm-test            Validate ISO in virtual machine first"
    echo "  --verify-all         Deep verification of all operations"
    echo
    echo "Examples:"
    echo "  sudo $0 Windows11.iso                     # Full automated installation"
    echo "  sudo $0 --dry-run Windows11.iso           # Preview operations only"
    echo "  sudo $0 --vm-test Windows11.iso           # Test in VM first"
    echo "  sudo $0 --verify-all Windows11.iso        # Maximum safety checks"
    echo "  sudo $0 --status                          # Check current progress"
    echo "  sudo $0 --reset                           # Start over"
}

main() {
    load_config
    
    init_logging "$@"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--status)
                show_status
                exit 0
                ;;
            -r|--reset)
                log "Resetting installation state..."
                clear_state
                success "Installation state reset"
                exit 0
                ;;
            -c|--config)
                log "Opening configuration file..."
                if command -v nano &> /dev/null; then
                    nano "$CONFIG_FILE"
                elif command -v vim &> /dev/null; then
                    vim "$CONFIG_FILE"
                else
                    echo "Configuration file: $CONFIG_FILE"
                fi
                exit 0
                ;;
            --dry-run)
                DRY_RUN=true
                warning "DRY-RUN MODE: Commands will be shown but not executed"
                shift
                ;;
            --vm-test)
                VM_TEST=true
                log "VM testing enabled"
                shift
                ;;
            --verify-all)
                VERIFY_ALL=true
                log "Comprehensive verification enabled"
                shift
                ;;
            --step1)
                [ $# -lt 2 ] && { error "ISO file required for step 1"; exit 1; }
                check_root
                step_prepare_iso "$2"
                exit $?
                ;;
            --step2)
                [ $# -lt 2 ] && { error "ISO file required for step 2"; exit 1; }
                check_root
                step_create_usb "$2"
                exit $?
                ;;
            --step3)
                check_root
                step_configure_boot
                exit $?
                ;;
            --step4)
                check_root
                step_final_reboot
                exit $?
                ;;
            -*)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                local iso_file="$1"
                break
                ;;
        esac
    done
    
    if [ -z "${iso_file:-}" ]; then
        show_help
        exit 1
    fi
            
            banner "=========================================="
            banner "      Windows Auto-Install System"
            banner "=========================================="
            echo
            
            validate_iso "$iso_file" || exit 1
            
            check_root
            
            run_full_workflow "$iso_file"
            ;;
    esac
}

trap 'echo; error "Installation interrupted"; save_state "interrupted"; exit 130' INT TERM

main "$@"