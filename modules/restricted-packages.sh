#!/bin/bash
# =============================================================================
# Restricted Packages Module
# =============================================================================
# Handles packages that need to be built from source due to licensing

# Source restricted packages configuration
# shellcheck source=../config/restricted-packages.conf
source "$CONFIG_DIR/restricted-packages.conf"

install_restricted_packages() {
    log "Setting up restricted packages..."
    
    # Use ALL_RESTRICTED_PACKAGES if defined, otherwise fall back to RESTRICTED_PACKAGES
    local packages_to_build=()
    if [[ -n "${ALL_RESTRICTED_PACKAGES:-}" ]]; then
        packages_to_build=("${ALL_RESTRICTED_PACKAGES[@]}")
    else
        packages_to_build=("${RESTRICTED_PACKAGES[@]}")
    fi
    
    # Skip if no restricted packages defined
    if [[ ${#packages_to_build[@]} -eq 0 ]]; then
        info "No restricted packages to install"
        return 0
    fi
    
    log "Found ${#packages_to_build[@]} restricted packages to process"
    
    # Set up void-packages repository
    setup_void_packages_repo
    
    # Enable restricted packages
    enable_restricted_packages
    
    # Build and install restricted packages
    build_restricted_packages "${packages_to_build[@]}"
    
    log "Restricted packages setup completed"
}

setup_void_packages_repo() {
    log "Setting up void-packages repository..."
    
    if [[ -d "$VOID_PACKAGES_DIR" ]]; then
        info "void-packages repository already exists at $VOID_PACKAGES_DIR"
        
        # Update existing repository
        log "Updating void-packages repository..."
        if ! (cd "$VOID_PACKAGES_DIR" && git pull); then
            warn "Failed to update void-packages repository"
        fi
    else
        log "Cloning void-packages repository..."
        if git clone "$VOID_PACKAGES_REPO" "$VOID_PACKAGES_DIR"; then
            log "void-packages repository cloned successfully"
        else
            error "Failed to clone void-packages repository"
        fi
    fi
}

enable_restricted_packages() {
    log "Enabling restricted packages in void-packages configuration..."
    
    # Ensure configuration directory exists
    mkdir -p "$(dirname "$VOID_PACKAGES_CONF")"
    
    # Check if already configured
    if grep -qxF "$XBPS_ALLOW_RESTRICTED" "$VOID_PACKAGES_CONF" 2>/dev/null; then
        info "Restricted packages already enabled"
    else
        echo "$XBPS_ALLOW_RESTRICTED" >> "$VOID_PACKAGES_CONF"
        log "Restricted packages enabled successfully"
    fi
}

build_restricted_packages() {
    local packages=("$@")
    log "Building and installing restricted packages..."
    
    # Initialize build environment
    setup_build_environment
    
    for pkg in "${packages[@]}"; do
        build_and_install_package "$pkg"
    done
    
    log "Restricted packages processing completed"
}

setup_build_environment() {
    log "Setting up build environment..."
    
    # Bootstrap the build environment if needed
    if [[ ! -d "$VOID_PACKAGES_DIR/hostdir" ]]; then
        log "Bootstrapping build environment..."
        (cd "$VOID_PACKAGES_DIR" && ./xbps-src binary-bootstrap) || {
            error "Failed to bootstrap build environment"
        }
    else
        info "Build environment already initialized"
    fi
}

build_and_install_package() {
    local package="$1"
    
    log "Processing restricted package: $package"
    
    # Check if package is already built
    if ls "$VOID_PACKAGES_DIR/hostdir/binpkgs" | grep -q "^${package}-" 2>/dev/null; then
        info "$package already built"
        
        # Try to install if not already installed
        if ! is_package_installed "$package"; then
            install_built_package "$package"
        else
            info "$package already installed"
        fi
    else
        log "Building $package from source..."
        build_package_from_source "$package"
        
        # Install after building
        install_built_package "$package"
    fi
}

build_package_from_source() {
    local package="$1"
    
    if ! (cd "$VOID_PACKAGES_DIR" && ./xbps-src pkg "$package"); then
        warn "Failed to build package: $package"
        return 1
    fi
    
    log "Successfully built package: $package"
}

install_built_package() {
    local package="$1"
    
    log "Installing built package: $package"
    
    # Find the built package file
    local pkg_file
    pkg_file=$(find "$VOID_PACKAGES_DIR/hostdir/binpkgs" -name "${package}-*.xbps" -type f | head -1)
    
    if [[ -n "$pkg_file" ]]; then
        if sudo xbps-install -y "$pkg_file"; then
            log "Successfully installed: $package"
        else
            warn "Failed to install built package: $package"
        fi
    else
        warn "Built package file not found for: $package"
    fi
}
