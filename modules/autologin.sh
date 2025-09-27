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
    
    # Configure shell to launch Hyprland
    configure_hyprland_startup "$username"
    
    log "Autologin setup completed"
}

create_autologin_service() {
    local username="$1"
    local service_dir="/etc/sv/agetty-autologin-tty1"
    local service_run="$service_dir/run"
    local service_link="/var/service/agetty-autologin-tty1"
    
    log "Creating autologin service for user '$username' on TTY1..."
    
    # Check if service already exists and is configured correctly
    if [[ -f "$service_run" ]]; then
        if grep -q "$username" "$service_run"; then
            info "Autologin service already configured for user '$username'"
        else
            log "Updating autologin service for user '$username'"
            create_service_files "$service_dir" "$username"
        fi
    else
        log "Creating new autologin service..."
        create_service_files "$service_dir" "$username"
    fi
    
    # Enable the service
    enable_autologin_service "$service_link" "$service_dir"
}

create_service_files() {
    local service_dir="$1"
    local username="$2"
    
    # Create service directory
    sudo mkdir -p "$service_dir"
    
    # Create run script
    sudo tee "$service_dir/run" > /dev/null <<EOF
#!/bin/sh
# Autologin service for $username on TTY1
exec agetty --autologin $username --noclear tty1 38400 linux
EOF
    
    # Make run script executable
    sudo chmod +x "$service_dir/run"
    
    # Create finish script (optional, for cleanup)
    sudo tee "$service_dir/finish" > /dev/null <<EOF
#!/bin/sh
# Cleanup script for autologin service
exec utmpset -w tty1
EOF
    
    sudo chmod +x "$service_dir/finish"
    
    log "Autologin service files created"
}

enable_autologin_service() {
    local service_link="$1"
    local service_dir="$2"
    
    if [[ -L "$service_link" ]]; then
        info "Autologin service already enabled"
    else
        log "Enabling autologin service..."
        sudo ln -s "$service_dir" "$service_link"
        log "Autologin service enabled successfully"
    fi
}

configure_hyprland_startup() {
    local username="$1"
    local user_home
    user_home=$(eval echo "~$username")
    local bash_profile="$user_home/.bash_profile"
    
    log "Configuring Hyprland startup in bash profile..."
    
    # Ensure the file exists
    touch "$bash_profile"
    
    # Check if Hyprland startup is already configured
    if grep -q "exec Hyprland" "$bash_profile"; then
        info "Hyprland startup already configured in .bash_profile"
        return 0
    fi
    
    # Add Hyprland startup configuration
    cat <<'EOF' >> "$bash_profile"

# Auto-start Hyprland on TTY1
if [[ "$(tty)" == "/dev/tty1" ]]; then
    # Set environment variables for Wayland
    export XDG_SESSION_TYPE=wayland
    export XDG_SESSION_DESKTOP=Hyprland
    export XDG_CURRENT_DESKTOP=Hyprland
    
    # Launch Hyprland
    exec Hyprland
fi
EOF
    
    log "Hyprland startup configuration added to .bash_profile"
}

# Function to disable autologin (for reverting changes)
disable_autologin() {
    local service_link="/var/service/agetty-autologin-tty1"
    local service_dir="/etc/sv/agetty-autologin-tty1"
    
    log "Disabling autologin service..."
    
    # Remove service link
    if [[ -L "$service_link" ]]; then
        sudo rm "$service_link"
        log "Autologin service disabled"
    else
        info "Autologin service was not enabled"
    fi
    
    # Optionally remove service directory
    if ask_yes_no "Remove autologin service directory completely?"; then
        sudo rm -rf "$service_dir"
        log "Autologin service directory removed"
    fi
}

# Function to configure alternative login managers (if needed)
configure_display_manager() {
    local dm="$1"
    
    case "$dm" in
        "sddm")
            configure_sddm_autologin
            ;;
        "gdm")
            configure_gdm_autologin
            ;;
        "lightdm")
            configure_lightdm_autologin
            ;;
        *)
            warn "Unsupported display manager: $dm"
            return 1
            ;;
    esac
}

configure_sddm_autologin() {
    local sddm_conf="/etc/sddm.conf"
    local username
    username=$(logname 2>/dev/null || echo "$USER")
    
    log "Configuring SDDM for autologin..."
    
    # Create or update SDDM configuration
    if [[ -f "$sddm_conf" ]]; then
        # Update existing configuration
        sudo sed -i "s/^User=.*/User=$username/" "$sddm_conf"
        sudo sed -i "s/^Session=.*/Session=hyprland/" "$sddm_conf"
    else
        # Create new configuration
        sudo tee "$sddm_conf" > /dev/null <<EOF
[Autologin]
User=$username
Session=hyprland

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
EOF
    fi
    
    log "SDDM autologin configured"
}
