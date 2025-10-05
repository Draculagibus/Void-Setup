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
    
    # Create oneshot service to enable autologin on next boot
    create_autologin_enabler
    
    log "Autologin setup completed"
    info "Autologin will be activated automatically on next reboot"
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
    
    info "Autologin service created (not enabled yet)"
}

create_autologin_enabler() {
    log "Creating autologin activation script for next boot..."
    
    # Create a simple shell script that will be run by rc.local on next boot
    sudo tee "/usr/local/bin/enable-autologin.sh" > /dev/null <<'EOF'
#!/bin/sh
# One-time script to enable autologin after installation

# Remove default getty on tty1
if [ -L "/var/service/agetty-tty1" ]; then
    rm -f /var/service/agetty-tty1
fi

# Enable autologin
if [ ! -L "/var/service/agetty-autologin-tty1" ]; then
    ln -s /etc/sv/agetty-autologin-tty1 /var/service/
fi

# Remove this script and rc.local entry
rm -f /usr/local/bin/enable-autologin.sh
sed -i '/enable-autologin.sh/d' /etc/rc.local

exit 0
EOF
    
    sudo chmod +x "/usr/local/bin/enable-autologin.sh"
    
    # Add to rc.local to run on next boot
    if [[ ! -f "/etc/rc.local" ]]; then
        sudo tee "/etc/rc.local" > /dev/null <<'EOF'
#!/bin/sh
# Local startup script
EOF
        sudo chmod +x "/etc/rc.local"
    fi
    
    # Add our script to rc.local if not already there
    if ! sudo grep -q "enable-autologin.sh" /etc/rc.local; then
        sudo sed -i '$i /usr/local/bin/enable-autologin.sh &' /etc/rc.local
    fi
    
    log "Autologin will be activated automatically on next boot"
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
