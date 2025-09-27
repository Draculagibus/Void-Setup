#!/bin/bash
# =============================================================================
# User Setup Module
# =============================================================================
# Handles user-specific configurations like cursor themes

install_cursor_theme() {
    log "Installing Bibata cursor theme..."
    
    local cursor_dir="$HOME/.icons/Bibata-Modern-Classic"
    local download_url="https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Classic.tar.xz"
    local archive_name="Bibata-Modern-Classic.tar.xz"
    local temp_dir="$SCRIPT_DIR/tmp"
    
    # Check if already installed
    if [[ -d "$cursor_dir" ]]; then
        info "Bibata cursor theme already installed"
        return 0
    fi
    
    # Create temporary directory
    mkdir -p "$temp_dir"
    cd "$temp_dir" || error "Failed to change to temporary directory"
    
    # Download cursor theme if not already present
    if [[ ! -f "$archive_name" ]]; then
        log "Downloading Bibata cursor theme..."
        if ! wget -nc "$download_url"; then
            warn "Failed to download Bibata cursor theme"
            return 1
        fi
    else
        info "Cursor theme archive already downloaded"
    fi
    
    # Extract archive
    log "Extracting cursor theme..."
    if ! tar -xf "$archive_name"; then
        warn "Failed to extract cursor theme"
        return 1
    fi
    
    # Create icons directory and install theme
    mkdir -p "$HOME/.icons"
    
    # Remove existing installation and install new one
    rm -rf "$cursor_dir"
    mv "Bibata-Modern-Classic" "$HOME/.icons/"
    
    # Clean up
    rm -f "$archive_name"
    cd "$SCRIPT_DIR" || error "Failed to return to script directory"
    
    log "Bibata cursor theme installed successfully"
}

# Function to set cursor theme in various desktop environments
set_cursor_theme() {
    local theme_name="Bibata-Modern-Classic"
    
    log "Setting cursor theme to $theme_name..."
    
    # For GTK applications
    if command -v gsettings &> /dev/null; then
        gsettings set org.gnome.desktop.interface cursor-theme "$theme_name"
        log "GTK cursor theme set"
    fi
    
    # For Qt applications (create/update .Xresources)
    local xresources="$HOME/.Xresources"
    if ! grep -q "Xcursor.theme" "$xresources" 2>/dev/null; then
        echo "Xcursor.theme: $theme_name" >> "$xresources"
        log "X11 cursor theme set in .Xresources"
    fi
    
    info "Cursor theme configuration completed"
}
