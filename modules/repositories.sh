#!/bin/bash
# =============================================================================
# Repository Management Module
# =============================================================================

# Source repository configuration
# shellcheck source=../config/repositories.conf
source "$CONFIG_DIR/repositories.conf"

setup_repositories() {
    log "Setting up repositories..."
    
    # Add custom repositories
    setup_custom_repositories
    
    # Install additional repositories
    install_additional_repositories
    
    # Update package database
    log "Updating package database..."
    sudo xbps-install -S
    
    log "Repository setup completed successfully"
}

setup_custom_repositories() {
    log "Setting up custom repositories..."
    
    # Check if any custom repositories are defined
    if [[ ${#CUSTOM_REPOSITORIES[@]} -eq 0 ]]; then
        info "No custom repositories to setup"
        return 0
    fi
    
    # Setup each custom repository
    for repo_config in "${CUSTOM_REPOSITORIES[@]}"; do
        # Parse format: "name|url|conf_file"
        IFS='|' read -r repo_name repo_url repo_conf <<< "$repo_config"
        
        # Validate parsed values
        if [[ -z "$repo_name" ]] || [[ -z "$repo_url" ]] || [[ -z "$repo_conf" ]]; then
            warn "Invalid repository configuration: $repo_config"
            warn "Expected format: 'name|url|conf_file_path'"
            continue
        fi
        
        setup_single_custom_repository "$repo_url" "$repo_conf" "$repo_name"
    done
    
    log "Custom repositories setup completed"
}

setup_single_custom_repository() {
    local repo_url="$1"
    local repo_conf="$2"
    local repo_name="$3"
    
    log "Setting up custom repository: $repo_name"
    
    if [[ -f "$repo_conf" ]]; then
        # Check if the URL in the config matches what we want
        if grep -q "$repo_url" "$repo_conf" 2>/dev/null; then
            info "$repo_name repository already configured correctly"
            return 0
        else
            warn "$repo_name repository config exists but URL differs, updating..."
        fi
    fi
    
    # Create repository configuration directory if needed
    local repo_dir
    repo_dir=$(dirname "$repo_conf")
    if [[ ! -d "$repo_dir" ]]; then
        sudo mkdir -p "$repo_dir"
    fi
    
    # Create or update repository configuration
    echo "repository=$repo_url" | sudo tee "$repo_conf" > /dev/null
    
    # Ensure proper permissions
    sudo chmod 644 "$repo_conf"
    
    log "$repo_name repository configured successfully at $repo_conf"
}

install_additional_repositories() {
    log "Installing additional repositories..."
    
    if [[ ${#ADDITIONAL_REPOS[@]} -eq 0 ]]; then
        info "No additional repositories to install"
        return 0
    fi
    
    for repo in "${ADDITIONAL_REPOS[@]}"; do
        if xbps-query -l | grep -qw "$repo"; then
            info "$repo is already installed"
        else
            log "Installing repository: $repo"
            if sudo xbps-install -Sy "$repo"; then
                log "Successfully installed repository: $repo"
            else
                warn "Failed to install repository: $repo"
            fi
        fi
    done
    
    log "Additional repositories processed"
}
