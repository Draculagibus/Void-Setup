#!/bin/bash
# =============================================================================
# Hyprland Environment Setup Script for Void Linux
# =============================================================================
# This script sets up a complete Hyprland desktop environment on Void Linux
# It's designed to be idempotent - safe to run multiple times
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# =============================================================================
# Configuration and Constants
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="$SCRIPT_DIR/config"
readonly MODULES_DIR="$SCRIPT_DIR/modules"
readonly LOG_FILE="$SCRIPT_DIR/install.log"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# =============================================================================
# Utility Functions
# =============================================================================

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

# Check if running as root (we don't want that)
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as a regular user."
    fi
}

# Check if sudo is available
check_sudo() {
    if ! command -v sudo &> /dev/null; then
        error "sudo is required but not installed. Please install sudo first."
    fi
}

# Validate config files exist
validate_config_files() {
    local required_files=(
        "$CONFIG_DIR/repositories.conf"
        "$CONFIG_DIR/packages.conf"
        "$CONFIG_DIR/restricted-packages.conf"
        "$CONFIG_DIR/services.conf"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Required config file not found: $file"
        fi
    done
    
    # Check if aliases.sh exists
    if [[ ! -f "$SCRIPT_DIR/aliases.sh" ]]; then
        error "Required file not found: $SCRIPT_DIR/aliases.sh"
    fi
}

# =============================================================================
# Source Module Functions
# =============================================================================

source_modules() {
    local modules=(
        "$MODULES_DIR/repositories.sh"
        "$MODULES_DIR/packages.sh"
        "$MODULES_DIR/restricted-packages.sh"
        "$MODULES_DIR/services.sh"
        "$MODULES_DIR/user-setup.sh"
        "$MODULES_DIR/dotfiles.sh"
        "$MODULES_DIR/autologin.sh"
        "$MODULES_DIR/git-setup.sh"
        "$MODULES_DIR/smart-aliases.sh"
    )
    
    for module in "${modules[@]}"; do
        if [[ -f "$module" ]]; then
            # shellcheck source=/dev/null
            source "$module"
        else
            error "Module not found: $module"
        fi
    done
}

# =============================================================================
# Main Installation Flow
# =============================================================================

main() {
    log "Starting Hyprland Environment Setup"
    
    # Pre-flight checks
    check_not_root
    check_sudo
    validate_config_files
    
    # Source all modules
    source_modules
    
    # Run installation steps
    setup_repositories
    install_packages
    install_restricted_packages
    configure_pipewire
    manage_services
    setup_user_permissions
    install_cursor_theme
    setup_dotfiles
    setup_autologin
    
    # Setup smart aliases
    setup_smart_aliases
    
    # Optional Git/SSH setup
    if ask_yes_no "Do you want to set up Git and SSH access?"; then
        setup_git_ssh
    fi
    
    log "Setup complete! 🎉"
    
    # Ask for reboot
    if ask_yes_no "Would you like to reboot now?"; then
        log "Rebooting system..."
        info "Autologin will be activated automatically after reboot"
        sudo reboot
    else
        info "Reboot skipped."
        warn "Autologin will be activated on your next reboot"
        info "To reboot later: sudo reboot"
    fi
}

# Helper function for yes/no prompts
ask_yes_no() {
    local prompt="$1"
    local response
    
    while true; do
        read -rp "$prompt [y/N]: " response
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]|"") return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# =============================================================================
# Script Entry Point
# =============================================================================

# Create log file
touch "$LOG_FILE"

# Run main function
main "$@"
