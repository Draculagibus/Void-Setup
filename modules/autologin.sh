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
    log "Creating one-time autologin enabler service..."
    
    # Create a oneshot service that runs once on boot
    sudo mkdir -p "/etc/sv/autologin-enabler"
    
    sudo tee "/etc/sv/autologin-enabler/run" > /dev/null <<'EOF'
#!/bin/sh
# One-time service to enable autologin after reboot

# Remove default getty on tty1
if [ -L "/var/service/agetty-tty1" ]; then
    rm -f /var/service/agetty-tty1
fi

# Enable autologin
if [ ! -L "/var/service/agetty-autologin-tty1" ]; then
    ln -s /etc/sv/agetty-autologin-tty1 /var/service/
fi

# Remove this oneshot service so it doesn't run again
rm -f /var/service/autologin-enabler

# Exit successfully
exit 0
EOF
    
    sudo chmod +x "/etc/sv/autologin-enabler/run"
    
    # Create a finish script to mark as oneshot
    sudo tee "/etc/sv/autologin-enabler/finish" > /dev/null <<'EOF'
#!/bin/sh
exec chpst -b autologin-enabler sleep 1
EOF
    
    sudo chmod +x "/etc/sv/autologin-enabler/finish"
    
    # Enable the oneshot service
    sudo ln -sf /etc/sv/autologin-enabler /var/service/
    
    log "Autologin enabler service created - will activate on next boot"
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
