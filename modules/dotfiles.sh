#!/bin/bash
# =============================================================================
# Dotfiles Management Module
# =============================================================================
# Handles dotfiles deployment using GNU Stow

setup_dotfiles() {
    log "Setting up dotfiles..."
    
    local dotfiles_dir="$SCRIPT_DIR/dotfiles"
    
    # Check if dotfiles directory exists
    if [[ ! -d "$dotfiles_dir" ]]; then
        warn "Dotfiles directory not found at $dotfiles_dir"
        
        # Ask user if they want to initialize a dotfiles directory
        if ask_yes_no "Would you like to create a dotfiles directory structure?"; then
            create_dotfiles_structure "$dotfiles_dir"
        else
            info "Skipping dotfiles setup"
            return 0
        fi
    fi
    
    deploy_dotfiles "$dotfiles_dir"
    
    log "Dotfiles setup completed"
}

create_dotfiles_structure() {
    local dotfiles_dir="$1"
    
    log "Creating dotfiles directory structure..."
    
    # Create basic directory structure
    mkdir -p "$dotfiles_dir"/{hypr,kitty,fish,micro,starship}
    
    # Create example configuration files
    create_example_configs "$dotfiles_dir"
    
    log "Dotfiles structure created at $dotfiles_dir"
    info "You can now add your configuration files to the appropriate subdirectories"
}

create_example_configs() {
    local dotfiles_dir="$1"
    
    # Create example Hyprland config
    mkdir -p "$dotfiles_dir/hypr/.config/hypr"
    cat > "$dotfiles_dir/hypr/.config/hypr/hyprland.conf" <<'EOF'
# Example Hyprland configuration
# This is a basic configuration - customize as needed

# Monitor configuration
monitor=,preferred,auto,1

# Input configuration
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = false
    }
    sensitivity = 0
}

# General configuration
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

# Example keybinds
bind = SUPER, Q, exec, kitty
bind = SUPER, C, killactive
bind = SUPER, M, exit
bind = SUPER, E, exec, dolphin
bind = SUPER, V, togglefloating
bind = SUPER, R, exec, wofi --show drun

# Move focus with mainMod + arrow keys
bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d
EOF

    # Create basic fish config
    mkdir -p "$dotfiles_dir/fish/.config/fish"
    cat > "$dotfiles_dir/fish/.config/fish/config.fish" <<'EOF'
# Fish shell configuration

# Initialize starship prompt if available
if command -v starship &> /dev/null
    starship init fish | source
end

# Add user binaries to PATH
fish_add_path ~/.local/bin
fish_add_path /usr/local/bin
EOF

    # Create kitty config
    mkdir -p "$dotfiles_dir/kitty/.config/kitty"
    cat > "$dotfiles_dir/kitty/.config/kitty/kitty.conf" <<'EOF'
# Kitty terminal configuration

# Font configuration
font_family JetBrains Mono
font_size 12.0

# Color scheme (adjust as needed)
background_opacity 0.95

# Window configuration
remember_window_size yes
initial_window_width 1200
initial_window_height 800
EOF

    # Create starship config
    mkdir -p "$dotfiles_dir/starship/.config"
    cat > "$dotfiles_dir/starship/.config/starship.toml" <<'EOF'
# Starship prompt configuration

[character]
success_symbol = "[➜](bold green)"
error_symbol = "[➜](bold red)"

[directory]
truncation_length = 3
truncation_symbol = "…/"

[git_branch]
symbol = "🌱 "

[git_status]
conflicted = "⚡"
ahead = "⇡"
behind = "⇣"
diverged = "⇕"
EOF

    # Create micro config
    mkdir -p "$dotfiles_dir/micro/.config/micro"
    cat > "$dotfiles_dir/micro/.config/micro/settings.json" <<'EOF'
{
    "autoclose": true,
    "autoindent": true,
    "autosave": true,
    "colorscheme": "monokai",
    "cursorline": true,
    "eofnewline": true,
    "ignorecase": false,
    "indentchar": " ",
    "infobar": true,
    "mkparents": false,
    "mouse": true,
    "pluginchannels": [
        "https://raw.githubusercontent.com/micro-editor/plugin-channel/master/channel.json"
    ],
    "pluginrepos": [],
    "rmtrailingws": false,
    "ruler": true,
    "savecursor": false,
    "savehistory": true,
    "saveundo": false,
    "scrollbar": false,
    "scrollmargin": 3,
    "scrollspeed": 2,
    "softwrap": false,
    "splitbottom": true,
    "splitright": true,
    "statusformatl": "$(filename) $(modified)($(line),$(col)) $(status.paste)| ft:$(opt:filetype) | $(opt:fileformat) | $(opt:encoding)",
    "statusformatr": "$(bind:ToggleKeyMenu): bindings, $(bind:ToggleHelp): help",
    "statusline": true,
    "sucmd": "sudo",
    "syntax": true,
    "tabmovement": false,
    "tabsize": 4,
    "tabstospaces": false,
    "termtitle": false,
    "useprimary": true
}
EOF

    log "Example configuration files created"
}

deploy_dotfiles() {
    local dotfiles_dir="$1"
    
    log "Deploying dotfiles using GNU Stow..."
    
    # Change to dotfiles directory
    cd "$dotfiles_dir" || {
        error "Failed to change to dotfiles directory: $dotfiles_dir"
    }
    
    # Get list of configuration packages (subdirectories)
    local packages=()
    while IFS= read -r -d '' dir; do
        local basename_dir
        basename_dir=$(basename "$dir")
        # Skip hidden directories and files
        if [[ "$basename_dir" != .* ]] && [[ -d "$dir" ]]; then
            packages+=("$basename_dir")
        fi
    done < <(find . -maxdepth 1 -type d -not -path . -print0)
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        warn "No configuration packages found in $dotfiles_dir"
        return 0
    fi
    
    log "Found configuration packages: ${packages[*]}"
    
    # Deploy each package
    for package in "${packages[@]}"; do
        deploy_package "$package"
    done
    
    # Return to original directory
    cd "$SCRIPT_DIR" || error "Failed to return to script directory"
    
    log "Dotfiles deployment completed"
}

deploy_package() {
    local package="$1"
    local target_dir="$HOME"
    
    log "Deploying configuration package: $package"
    
    # Check if package directory exists and has content
    if [[ ! -d "$package" ]]; then
        warn "Package directory '$package' not found"
        return 1
    fi
    
    # Check if package has any files to deploy
    if ! find "$package" -type f | head -1 | grep -q .; then
        info "Package '$package' is empty, skipping"
        return 0
    fi
    
    # Use stow to create symlinks
    if stow --target="$target_dir" "$package" 2>/dev/null; then
        log "Successfully deployed package: $package"
    else
        # Try restow in case of conflicts
        warn "Conflicts detected for package '$package', attempting restow..."
        if stow --target="$target_dir" --restow "$package"; then
            log "Successfully restowed package: $package"
        else
            warn "Failed to deploy package: $package"
            info "You may need to resolve conflicts manually"
            
            # Show what conflicts exist
            show_stow_conflicts "$package" "$target_dir"
        fi
    fi
}

show_stow_conflicts() {
    local package="$1"
    local target_dir="$2"
    
    warn "Checking for conflicts in package: $package"
    
    # Find files that would conflict
    find "$package" -type f | while read -r file; do
        local target_file="$target_dir/${file#$package/}"
        if [[ -e "$target_file" ]] && [[ ! -L "$target_file" ]]; then
            warn "Conflict: $target_file exists and is not a symlink"
        fi
    done
}

# Function to backup existing dotfiles before deployment
backup_existing_dotfiles() {
    local backup_dir="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
    
    log "Creating backup of existing dotfiles at $backup_dir"
    
    # Common dotfiles to backup
    local files_to_backup=(
        ".bashrc"
        ".bash_profile"
        ".vimrc"
        ".tmux.conf"
        ".gitconfig"
        ".config/hypr"
        ".config/kitty"
        ".config/fish"
        ".config/micro"
        ".config/starship.toml"
    )
    
    mkdir -p "$backup_dir"
    local backed_up_count=0
    
    for file in "${files_to_backup[@]}"; do
        local full_path="$HOME/$file"
        if [[ -e "$full_path" ]] && [[ ! -L "$full_path" ]]; then
            local backup_path="$backup_dir/$file"
            mkdir -p "$(dirname "$backup_path")"
            cp -r "$full_path" "$backup_path" 2>/dev/null && {
                log "Backed up: $file"
                ((backed_up_count++))
            }
        fi
    done
    
    if [[ $backed_up_count -gt 0 ]]; then
        log "Backup completed: $backed_up_count files backed up to $backup_dir"
    else
        info "No files needed backing up"
        rmdir "$backup_dir" 2>/dev/null
    fi
}

# Function to remove stowed dotfiles (for cleanup/uninstall)
remove_dotfiles() {
    local dotfiles_dir="$1"
    
    log "Removing stowed dotfiles..."
    
    cd "$dotfiles_dir" || return 1
    
    local removed_count=0
    # Remove all stowed packages
    for package in */; do
        if [[ -d "$package" ]]; then
            local package_name
            package_name=$(basename "$package")
            if stow --target="$HOME" --delete "$package_name" 2>/dev/null; then
                log "Removed package: $package_name"
                ((removed_count++))
            else
                warn "Failed to remove package: $package_name"
            fi
        fi
    done
    
    cd "$SCRIPT_DIR" || return 1
    
    log "Dotfiles removal completed: $removed_count packages removed"
}

# Function to update dotfiles (restow all packages)
update_dotfiles() {
    local dotfiles_dir="$SCRIPT_DIR/dotfiles"
    
    if [[ ! -d "$dotfiles_dir" ]]; then
        warn "Dotfiles directory not found"
        return 1
    fi
    
    log "Updating all dotfiles..."
    deploy_dotfiles "$dotfiles_dir"
}
