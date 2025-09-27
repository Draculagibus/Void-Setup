#!/bin/bash
# =============================================================================
# Package Installation Module
# =============================================================================

# Source package configuration
# shellcheck source=../config/packages.conf
source "$CONFIG_DIR/packages.conf"

install_packages() {
    log "Starting package installation..."
    
    # Check which packages need to be installed
    local packages_to_install=()
    local already_installed=()
    
    for pkg in "${ALL_PACKAGES[@]}"; do
        if is_package_installed "$pkg"; then
            already_installed+=("$pkg")
        else
            packages_to_install+=("$pkg")
        fi
    done
    
    # Report status
    if [[ ${#already_installed[@]} -gt 0 ]]; then
        info "${#already_installed[@]} packages already installed"
    fi
    
    # Install missing packages
    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        log "Installing ${#packages_to_install[@]} missing packages..."
        install_package_batch "${packages_to_install[@]}"
    else
        info "All packages are already installed"
    fi
    
    # Install manually managed packages
    install_manual_packages
    
    log "Package installation completed successfully"
}

is_package_installed() {
    local package="$1"
    xbps-query -l | grep -qw "^ii $package"
}

install_package_batch() {
    local packages=("$@")
    
    log "Installing packages: ${packages[*]}"
    
    # Install in batches to handle potential failures gracefully
    local batch_size=10
    local i=0
    
    while [[ $i -lt ${#packages[@]} ]]; do
        local batch=("${packages[@]:$i:$batch_size}")
        
        if ! sudo xbps-install -Sy "${batch[@]}"; then
            warn "Batch installation failed, trying individual packages..."
            install_packages_individually "${batch[@]}"
        else
            log "Successfully installed batch: ${batch[*]}"
        fi
        
        ((i += batch_size))
    done
}

install_packages_individually() {
    local packages=("$@")
    
    for pkg in "${packages[@]}"; do
        if sudo xbps-install -Sy "$pkg"; then
            log "Successfully installed: $pkg"
        else
            warn "Failed to install: $pkg"
        fi
    done
}

install_manual_packages() {
    log "Installing manually managed packages..."
    
    install_hyprshot
    
    log "Manual package installation completed"
}

install_hyprshot() {
    log "Installing Hyprshot screenshot tool..."
    
    local hyprshot_dir="$SCRIPT_DIR/tmp/Hyprshot"
    local install_path="/usr/local/bin/hyprshot"
    
    # Create temporary directory
    mkdir -p "$(dirname "$hyprshot_dir")"
    
    # Check if already installed and up to date
    if [[ -x "$install_path" ]]; then
        info "Hyprshot already installed, checking for updates..."
    fi
    
    # Clean up any existing directory
    rm -rf "$hyprshot_dir"
    
    # Clone repository
    if git clone https://github.com/Gustash/hyprshot.git "$hyprshot_dir"; then
        chmod +x "$hyprshot_dir/hyprshot"
        
        # Remove existing installation and install new version
        sudo rm -rf "$install_path"
        sudo mv "$hyprshot_dir/hyprshot" "$install_path"
        
        # Clean up
        rm -rf "$hyprshot_dir"
        
        log "Hyprshot installed successfully"
    else
        warn "Failed to clone Hyprshot repository"
    fi
}

configure_pipewire() {
    log "Configuring PipeWire audio system..."
    
    local wireplumber_conf="/etc/pipewire/pipewire.conf.d/10-wireplumber.conf"
    local wireplumber_example="/usr/share/examples/wireplumber/10-wireplumber.conf"
    
    if [[ -L "$wireplumber_conf" ]]; then
        info "WirePlumber configuration already linked"
    else
        # Create directory if it doesn't exist
        sudo mkdir -p "$(dirname "$wireplumber_conf")"
        
        # Link configuration if example exists
        if [[ -f "$wireplumber_example" ]]; then
            sudo ln -s "$wireplumber_example" "$wireplumber_conf"
            log "WirePlumber configuration linked successfully"
        else
            warn "WirePlumber example configuration not found at $wireplumber_example"
        fi
    fi
    
    log "PipeWire configuration completed"
}
