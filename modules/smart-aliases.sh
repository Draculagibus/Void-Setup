#!/bin/bash
# =============================================================================
# Smart Aliases Setup Module
# =============================================================================

setup_smart_aliases() {
    log "Setting up smart package management aliases..."
    
    local username
    username=$(logname 2>/dev/null || echo "$USER")
    local user_home
    user_home=$(eval echo "~$username")
    
    # Verify aliases.sh exists
    if [[ ! -f "$SCRIPT_DIR/aliases.sh" ]]; then
        error "aliases.sh not found at $SCRIPT_DIR/aliases.sh"
    fi
    
    # Make aliases.sh executable
    chmod +x "$SCRIPT_DIR/aliases.sh"
    
    # Setup for different shells
    setup_bash_aliases "$user_home"
    setup_fish_aliases "$user_home"
    
    log "Smart aliases setup completed"
    info "Aliases will be available after you restart your shell or run:"
    info "  source $SCRIPT_DIR/aliases.sh"
}

setup_bash_aliases() {
    local user_home="$1"
    local bashrc="$user_home/.bashrc"
    
    log "Setting up bash aliases..."
    
    # Ensure .bashrc exists
    touch "$bashrc"
    
    # Check if already configured
    if grep -q "source.*aliases.sh" "$bashrc"; then
        info "Bash aliases already configured"
        return 0
    fi
    
    # Add source line to .bashrc
    cat >> "$bashrc" <<EOF

# Smart package management aliases for Void Setup
if [ -f "$SCRIPT_DIR/aliases.sh" ]; then
    source "$SCRIPT_DIR/aliases.sh"
fi
EOF
    
    log "Bash aliases configured in $bashrc"
}

setup_fish_aliases() {
    local user_home="$1"
    local fish_config_dir="$user_home/.config/fish"
    local fish_config="$fish_config_dir/config.fish"
    
    # Skip if fish config doesn't exist (fish not used)
    if [[ ! -d "$fish_config_dir" ]]; then
        info "Fish shell not configured, skipping fish aliases"
        return 0
    fi
    
    log "Setting up fish aliases..."
    
    # Ensure config.fish exists
    mkdir -p "$fish_config_dir"
    touch "$fish_config"
    
    # Check if already configured
    if grep -q "source.*aliases.sh" "$fish_config"; then
        info "Fish aliases already configured"
        return 0
    fi
    
    # Add source line to fish config
    cat >> "$fish_config" <<EOF

# Smart package management aliases for Void Setup
if test -f "$SCRIPT_DIR/aliases.sh"
    source "$SCRIPT_DIR/aliases.sh"
end
EOF
    
    log "Fish aliases configured in $fish_config"
}

# Function to test aliases after setup
test_smart_aliases() {
    log "Testing smart aliases functionality..."
    
    # Source the aliases
    if source "$SCRIPT_DIR/aliases.sh" 2>/dev/null; then
        # Test if functions are available
        if command -v xbps-smart-help &> /dev/null; then
            log "Smart aliases test successful"
        else
            warn "Smart aliases test failed - functions not available"
        fi
    else
        warn "Could not source aliases.sh"
    fi
}
