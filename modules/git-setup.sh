#!/bin/bash
# =============================================================================
# Git and SSH Setup Module
# =============================================================================
# Handles Git configuration and SSH key generation

setup_git_ssh() {
    log "Setting up Git and SSH configuration..."
    
    # Setup SSH key
    setup_ssh_key
    
    # Configure Git (optional)
    if ask_yes_no "Would you like to configure Git user information?"; then
        configure_git_user
    fi
    
    log "Git and SSH setup completed"
}

setup_ssh_key() {
    local ssh_dir="$HOME/.ssh"
    local key_path="$ssh_dir/id_ed25519"
    
    log "Setting up SSH key..."
    
    # Create SSH directory if it doesn't exist
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Check if SSH key already exists
    if [[ -f "$key_path" ]]; then
        info "SSH key already exists at $key_path"
        
        if ask_yes_no "Would you like to display the public key?"; then
            display_public_key "$key_path"
        fi
        
        return 0
    fi
    
    # Generate new SSH key
    generate_ssh_key "$key_path"
    
    # Add key to SSH agent
    add_key_to_agent "$key_path"
    
    # Display public key and instructions
    display_public_key "$key_path"
    show_git_instructions
}

generate_ssh_key() {
    local key_path="$1"
    local email
    
    # Get email for SSH key
    while [[ -z "$email" ]]; do
        read -rp "Enter your email address for the SSH key: " email
        if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            warn "Invalid email format. Please try again."
            email=""
        fi
    done
    
    log "Generating SSH key with email: $email"
    
    # Generate ED25519 key (more secure than RSA)
    if ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""; then
        log "SSH key generated successfully"
        chmod 600 "$key_path"
        chmod 644 "$key_path.pub"
    else
        error "Failed to generate SSH key"
    fi
}

add_key_to_agent() {
    local key_path="$1"
    
    log "Adding SSH key to SSH agent..."
    
    # Start SSH agent if not running
    if ! pgrep -x ssh-agent > /dev/null; then
        eval "$(ssh-agent -s)" > /dev/null
        log "Started SSH agent"
    fi
    
    # Add key to agent
    if ssh-add "$key_path" 2>/dev/null; then
        log "SSH key added to agent"
    else
        warn "Failed to add SSH key to agent"
    fi
}

display_public_key() {
    local key_path="$1"
    local pub_key_path="$key_path.pub"
    
    if [[ ! -f "$pub_key_path" ]]; then
        warn "Public key not found at $pub_key_path"
        return 1
    fi
    
    log "SSH public key:"
    echo
    cat "$pub_key_path"
    echo
    
    # Try to copy to clipboard
    copy_to_clipboard "$pub_key_path"
}

copy_to_clipboard() {
    local file_path="$1"
    
    # Try different clipboard utilities (Wayland first, then X11, then macOS)
    if command -v wl-copy &>/dev/null; then
        wl-copy < "$file_path"
        log "Public key copied to clipboard (via wl-copy)"
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard < "$file_path"
        log "Public key copied to clipboard (via xclip)"
    elif command -v xsel &>/dev/null; then
        xsel --clipboard --input < "$file_path"
        log "Public key copied to clipboard (via xsel)"
    elif command -v pbcopy &>/dev/null; then
        pbcopy < "$file_path"
        log "Public key copied to clipboard (via pbcopy)"
    else
        info "No clipboard utility found. Public key displayed above."
    fi
}

show_git_instructions() {
    echo
    info "=== SSH Key Setup Instructions ==="
    echo
    echo "1. Add this SSH key to your Git hosting service:"
    echo "   • GitHub: https://github.com/settings/keys"
    echo "   • GitLab: https://gitlab.com/-/profile/keys"
    echo "   • Bitbucket: https://bitbucket.org/account/settings/ssh-keys/"
    echo
    echo "2. Test your SSH connection:"
    echo "   • GitHub: ssh -T git@github.com"
    echo "   • GitLab: ssh -T git@gitlab.com"
    echo
}

configure_git_user() {
    local current_name
    local current_email
    
    log "Configuring Git user information..."
    
    # Get current Git configuration
    current_name=$(git config --global user.name 2>/dev/null || echo "")
    current_email=$(git config --global user.email 2>/dev/null || echo "")
    
    # Show current configuration
    if [[ -n "$current_name" ]] || [[ -n "$current_email" ]]; then
        info "Current Git configuration:"
        [[ -n "$current_name" ]] && echo "  Name: $current_name"
        [[ -n "$current_email" ]] && echo "  Email: $current_email"
        echo
        
        if ask_yes_no "Keep current Git configuration?"; then
            info "Keeping current Git configuration"
            return 0
        fi
    fi
    
    # Configure name
    local git_name
    while [[ -z "$git_name" ]]; do
        read -rp "Enter your full name for Git: " git_name
    done
    
    # Configure email
    local git_email
    while [[ -z "$git_email" ]]; do
        read -rp "Enter your email for Git: " git_email
        if [[ ! "$git_email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            warn "Invalid email format. Please try again."
            git_email=""
        fi
    done
    
    # Set Git configuration
    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    
    # Set some useful Git defaults
    configure_git_defaults
    
    log "Git user configuration completed"
    info "Name: $git_name"
    info "Email: $git_email"
}

configure_git_defaults() {
    log "Setting up Git defaults..."
    
    # Set default branch name to main
    git config --global init.defaultBranch main
    
    # Set up better diff and merge tools
    git config --global diff.tool vimdiff
    git config --global merge.tool vimdiff
    
    # Enable colored output
    git config --global color.ui auto
    
    # Set up push behavior
    git config --global push.default simple
    git config --global push.autoSetupRemote true
    
    # Enable helpful features
    git config --global pull.rebase true
    git config --global rebase.autoStash true
    
    log "Git defaults configured"
}

# Function to test SSH connection to common Git services
test_ssh_connections() {
    local services=(
        "github.com"
        "gitlab.com"
        "bitbucket.org"
    )
    
    log "Testing SSH connections to Git services..."
    
    for service in "${services[@]}"; do
        info "Testing connection to $service..."
        if ssh -T "git@$service" -o ConnectTimeout=10 -o BatchMode=yes 2>&1 | grep -q "successfully authenticated"; then
            log "✓ Connection to $service successful"
        else
            warn "✗ Connection to $service failed or not configured"
        fi
    done
}
