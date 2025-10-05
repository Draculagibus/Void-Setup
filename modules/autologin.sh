#!/bin/bash
# =============================================================================
# Autologin Setup Module
# =============================================================================
# Configures automatic login and Hyprland startup

setup_autologin() {
    log "Setting up autologin and Hyprland startup..."
    
    local username
    username=$(logname 2>/dev/null || echo "$USER")
    
    if [[ -z "$username" ]]; then
        error "Unable to determine username for autologin setup"
    fi
    
    # Create autologin service
    create_autologin_service "$username"
    
    # Configure bash to launch Hyprland
    configure_hyprland_startup "$username"
    
    log "Autologin setup completed"
}

create_autologin_service() {
    local username="$1"
    
    log "Creating autologin service for $username on TTY1..."
    
    # Create runit service for autologin
    sudo mkdir -p "/etc/sv/agetty-autologin-tty1"
    
    sudo tee "/etc/sv/agetty-autologin-tty1/run" > /dev/null <<EOF
#!/bin/sh
exec agetty --autologin $username --noclear tty1 38400 linux
EOF
    
    sudo chmod +x "/etc/sv/agetty-autologin-tty1/run"
    
    # DON'T enable the service yet - will be enabled after reboot prompt
    info "Autologin service created (will be enabled on reboot)"
}

enable_autologin_service() {
    log "Enabling autologin service..."
    
    if [[ ! -e "/var/service/agetty-autologin-tty1" ]]; then
        sudo ln -s "/etc/sv/agetty-autologin-tty1" "/var/service/"
        log "Autologin service enabled"
    else
        info "Autologin service already active"
    fi
}

configure_hyprland_startup() {
    local username="$1"
    local bash_profile="/home/$username/.bash_profile"
    
    log "Configuring bash to launch Hyprland on TTY1..."
    
    # Ensure .bash_profile exists
    touch "$bash_profile"
    
    # Add Hyprland exec block if not present
    if ! grep -q "exec Hyprland" "$bash_profile"; then
        cat <<'EOF' >> "$bash_profile"

# Autostart Hyprland on tty1
if [ "$(tty)" = "/dev/tty1" ]; then
    exec Hyprland
fi
EOF
        log "Hyprland launch added to .bash_profile"
    else
        info "Hyprland launch already present in .bash_profile"
    fi
}
