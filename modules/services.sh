#!/bin/bash
# =============================================================================
# Services Management Module
# =============================================================================

# Source services configuration
# shellcheck source=../config/services.conf
source "$CONFIG_DIR/services.conf"

manage_services() {
    log "Managing system services..."
    
    enable_system_services
    
    log "System services management completed"
}

enable_system_services() {
    log "Enabling system services..."
    
    for service in "${!SYSTEM_SERVICES[@]}"; do
        enable_service "$service" "${SYSTEM_SERVICES[$service]}"
    done
    
    log "System services enabled successfully"
}

enable_service() {
    local service="$1"
    local description="$2"
    local service_link="/var/service/$service"
    local service_dir="/etc/sv/$service"
    
    # Check if service directory exists first
    if [[ ! -d "$service_dir" ]]; then
        warn "Service directory not found for '$service' at $service_dir - skipping"
        return 1
    fi
    
    if [[ -L "$service_link" ]]; then
        info "Service '$service' already enabled — $description"
    else
        log "Enabling service '$service' — $description"
        if sudo ln -s "$service_dir" "$service_link"; then
            log "Successfully enabled service '$service'"
            # Give service time to start
            sleep 1
        else
            warn "Failed to enable service '$service'"
        fi
    fi
}

setup_user_permissions() {
    log "Setting up user permissions and groups..."
    
    local current_user="$USER"
    
    for group in "${USER_GROUPS[@]}"; do
        add_user_to_group "$current_user" "$group"
    done
    
    log "User permissions setup completed"
}

add_user_to_group() {
    local user="$1"
    local group="$2"
    
    if id -nG "$user" | grep -qw "$group"; then
        info "User '$user' is already in group '$group'"
    else
        log "Adding user '$user' to group '$group'"
        if sudo usermod -aG "$group" "$user"; then
            log "Successfully added user '$user' to group '$group'"
        else
            warn "Failed to add user '$user' to group '$group'"
        fi
    fi
}

# Function to check service status (useful for debugging)
check_service_status() {
    local service="$1"
    local service_link="/var/service/$service"
    
    if [[ -L "$service_link" ]]; then
        if sv status "$service" &>/dev/null; then
            info "Service '$service' is running"
        else
            warn "Service '$service' is enabled but not running"
        fi
    else
        info "Service '$service' is not enabled"
    fi
}
