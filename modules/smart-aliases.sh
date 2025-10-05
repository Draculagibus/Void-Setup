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
    
    # Setup bash aliases
    setup_bash_aliases "$user_home"
    
    log "Smart aliases setup completed"
    info "Aliases will be available after: source ~/.bashrc"
}

setup_bash_aliases() {
    local user_home="$1"
    local bashrc="$user_home/.bashrc"
    
    log "Configuring bash aliases..."
    
    # Ensure .bashrc exists
    touch "$bashrc"
    
    # Check if already configured
    if grep -q "source.*aliases.sh" "$bashrc" 2>/dev/null; then
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
