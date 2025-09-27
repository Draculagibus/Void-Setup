#!/bin/bash
# =============================================================================
# Smart Package Management Aliases
# =============================================================================
# These aliases automatically update your config files when you install/remove
# packages, enable services, add groups, etc.
#
# Usage: source this file in your shell profile

# Get the directory where this script is located
VOID_SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$VOID_SETUP_DIR/config"

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color

# Helper function for colored output
smart_echo() {
    echo -e "${GREEN}[SMART]${NC} $*"
}

smart_warn() {
    echo -e "${YELLOW}[SMART]${NC} $*"
}

smart_error() {
    echo -e "${RED}[SMART]${NC} $*"
}

# =============================================================================
# Smart Package Installation
# =============================================================================

xbps-smart-install() {
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "Usage: xbps-smart-install package1 [package2 ...]"
        return 1
    fi
    
    smart_echo "Installing packages: ${packages[*]}"
    
    # Try to install the packages
    if sudo xbps-install -S "${packages[@]}"; then
        smart_echo "Installation successful, updating config..."
        
        # Add successfully installed packages to config
        for package in "${packages[@]}"; do
            add_package_to_config "$package"
        done
        
        smart_echo "Config updated! Commit changes with: git add config/ && git commit -m 'Add packages: ${packages[*]}'"
    else
        smart_error "Installation failed, config not updated"
        return 1
    fi
}

add_package_to_config() {
    local package="$1"
    local packages_conf="$CONFIG_DIR/packages.conf"
    
    # Check if package already in config
    if grep -q "\"$package\"" "$packages_conf" 2>/dev/null; then
        smart_warn "$package already in config"
        return 0
    fi
    
    # Add to CUSTOM_PACKAGES section
    if grep -q "CUSTOM_PACKAGES=" "$packages_conf"; then
        # Add after CUSTOM_PACKAGES=( line
        sed -i "/CUSTOM_PACKAGES=(/a\\    \"$package\"                # Added $(date +%Y-%m-%d)" "$packages_conf"
        smart_echo "Added $package to CUSTOM_PACKAGES"
    else
        smart_error "Could not find CUSTOM_PACKAGES section in $packages_conf"
        return 1
    fi
}

# =============================================================================
# Smart Package Removal
# =============================================================================

xbps-smart-remove() {
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "Usage: xbps-smart-remove package1 [package2 ...]"
        return 1
    fi
    
    smart_echo "Removing packages: ${packages[*]}"
    
    # Remove the packages
    if sudo xbps-remove -R "${packages[@]}"; then
        smart_echo "Removal successful, updating config..."
        
        # Remove from config
        for package in "${packages[@]}"; do
            remove_package_from_config "$package"
        done
        
        smart_echo "Config updated! Commit changes with: git add config/ && git commit -m 'Remove packages: ${packages[*]}'"
    else
        smart_error "Removal failed, config not updated"
        return 1
    fi
}

remove_package_from_config() {
    local package="$1"
    local packages_conf="$CONFIG_DIR/packages.conf"
    
    # Remove the line containing the package
    if grep -q "\"$package\"" "$packages_conf"; then
        sed -i "/\"$package\"/d" "$packages_conf"
        smart_echo "Removed $package from config"
    else
        smart_warn "$package not found in config"
    fi
}

# =============================================================================
# Smart Service Management
# =============================================================================

xbps-smart-service() {
    local service="$1"
    local description="$2"
    
    if [[ -z "$service" ]]; then
        echo "Usage: xbps-smart-service service-name [\"description\"]"
        return 1
    fi
    
    if [[ -z "$description" ]]; then
        description="Service added $(date +%Y-%m-%d)"
    fi
    
    smart_echo "Enabling service: $service"
    
    # Enable the service
    if sudo ln -sf "/etc/sv/$service" "/var/service/$service" 2>/dev/null; then
        smart_echo "Service enabled, updating config..."
        add_service_to_config "$service" "$description"
        smart_echo "Config updated! Commit changes with: git add config/ && git commit -m 'Add service: $service'"
    else
        smart_error "Failed to enable service $service (does /etc/sv/$service exist?)"
        return 1
    fi
}

add_service_to_config() {
    local service="$1"
    local description="$2"
    local services_conf="$CONFIG_DIR/services.conf"
    
    # Check if service already in config
    if grep -q "\\[\"$service\"\\]" "$services_conf" 2>/dev/null; then
        smart_warn "$service already in config"
        return 0
    fi
    
    # Add to SYSTEM_SERVICES section
    if grep -q "declare -A SYSTEM_SERVICES" "$services_conf"; then
        # Find the closing ) of SYSTEM_SERVICES and add before it
        sed -i "/declare -A SYSTEM_SERVICES/,/^)/ { /^)/i\\    [\"$service\"]=\"$description\"
        }" "$services_conf"
        smart_echo "Added $service to SYSTEM_SERVICES"
    else
        smart_error "Could not find SYSTEM_SERVICES section in $services_conf"
        return 1
    fi
}

# =============================================================================
# Smart Group Management  
# =============================================================================

xbps-smart-group() {
    local group="$1"
    
    if [[ -z "$group" ]]; then
        echo "Usage: xbps-smart-group group-name"
        return 1
    fi
    
    smart_echo "Adding user $USER to group: $group"
    
    # Add user to group
    if sudo usermod -aG "$group" "$USER"; then
        smart_echo "Group added, updating config..."
        add_group_to_config "$group"
        smart_echo "Config updated! Commit changes with: git add config/ && git commit -m 'Add group: $group'"
    else
        smart_error "Failed to add user to group $group"
        return 1
    fi
}

add_group_to_config() {
    local group="$1"
    local services_conf="$CONFIG_DIR/services.conf"
    
    # Check if group already in config
    if grep -q "\"$group\"" "$services_conf" 2>/dev/null; then
        smart_warn "$group already in config"
        return 0
    fi
    
    # Add to USER_GROUPS section
    if grep -q "USER_GROUPS=" "$services_conf"; then
        sed -i "/USER_GROUPS=(/a\\    \"$group\"        # Added $(date +%Y-%m-%d)" "$services_conf"
        smart_echo "Added $group to USER_GROUPS"
    else
        smart_error "Could not find USER_GROUPS section in $services_conf"
        return 1
    fi
}

# =============================================================================
# Smart Repository Management
# =============================================================================

xbps-smart-repo() {
    local name="$1"
    local url="$2"
    local conf_path="$3"
    
    if [[ -z "$name" ]] || [[ -z "$url" ]]; then
        echo "Usage: xbps-smart-repo \"name\" \"url\" [\"conf-path\"]"
        echo "Example: xbps-smart-repo \"myrepo\" \"https://example.com/repo\" \"/etc/xbps.d/myrepo.conf\""
        return 1
    fi
    
    # Default conf path if not provided
    if [[ -z "$conf_path" ]]; then
        conf_path="/etc/xbps.d/${name}.conf"
    fi
    
    smart_echo "Adding repository: $name"
    
    # Create the repository config
    if echo "repository=$url" | sudo tee "$conf_path" > /dev/null; then
        sudo chmod 644 "$conf_path"
        smart_echo "Repository added, updating config..."
        add_repo_to_config "$name" "$url" "$conf_path"
        smart_echo "Config updated! Run 'sudo xbps-install -S' to sync"
        smart_echo "Commit changes with: git add config/ && git commit -m 'Add repo: $name'"
    else
        smart_error "Failed to create repository config"
        return 1
    fi
}

add_repo_to_config() {
    local name="$1"
    local url="$2"
    local conf_path="$3"
    local repos_conf="$CONFIG_DIR/repositories.conf"
    
    # Check if repo already in config
    if grep -q "\"$name|" "$repos_conf" 2>/dev/null; then
        smart_warn "$name already in config"
        return 0
    fi
    
    # Add to CUSTOM_REPOSITORIES section
    if grep -q "CUSTOM_REPOSITORIES=" "$repos_conf"; then
        sed -i "/CUSTOM_REPOSITORIES=(/a\\    \"$name|$url|$conf_path\"" "$repos_conf"
        smart_echo "Added $name to CUSTOM_REPOSITORIES"
    else
        smart_error "Could not find CUSTOM_REPOSITORIES section in $repos_conf"
        return 1
    fi
}

# =============================================================================
# Smart Restricted Package Management
# =============================================================================

xbps-smart-restricted() {
    local package="$1"
    
    if [[ -z "$package" ]]; then
        echo "Usage: xbps-smart-restricted package-name"
        return 1
    fi
    
    smart_echo "Adding restricted package: $package"
    smart_echo "Note: This will be built from source on next 'make install'"
    
    add_restricted_to_config "$package"
    smart_echo "Config updated! Run 'make install' to build and install"
    smart_echo "Commit changes with: git add config/ && git commit -m 'Add restricted package: $package'"
}

add_restricted_to_config() {
    local package="$1"
    local restricted_conf="$CONFIG_DIR/restricted-packages.conf"
    
    # Check if package already in config
    if grep -q "\"$package\"" "$restricted_conf" 2>/dev/null; then
        smart_warn "$package already in restricted config"
        return 0
    fi
    
    # Add to RESTRICTED_PACKAGES section
    if grep -q "RESTRICTED_PACKAGES=" "$restricted_conf"; then
        sed -i "/RESTRICTED_PACKAGES=(/a\\    \"$package\"                # Added $(date +%Y-%m-%d)" "$restricted_conf"
        smart_echo "Added $package to RESTRICTED_PACKAGES"
    else
        smart_error "Could not find RESTRICTED_PACKAGES section in $restricted_conf"
        return 1
    fi
}

# =============================================================================
# Helper Functions
# =============================================================================

# Show current config status
xbps-smart-status() {
    smart_echo "Current configuration status:"
    echo
    echo "Packages: $(grep -c '\".*\"' "$CONFIG_DIR/packages.conf" 2>/dev/null || echo "0")"
    echo "Services: $(grep -c '\[.*\]=' "$CONFIG_DIR/services.conf" 2>/dev/null || echo "0")"  
    echo "Repositories: $(grep -c '\".*|.*|.*\"' "$CONFIG_DIR/repositories.conf" 2>/dev/null || echo "0")"
    echo "Restricted: $(grep -c '\".*\"' "$CONFIG_DIR/restricted-packages.conf" 2>/dev/null || echo "0")"
    echo
    echo "Git status:"
    cd "$VOID_SETUP_DIR" && git status --porcelain config/
}

# Quick help
xbps-smart-help() {
    echo "Smart Package Management Commands:"
    echo "  xbps-smart-install pkg [pkg2 ...]    # Install and add to config"
    echo "  xbps-smart-remove pkg [pkg2 ...]     # Remove and remove from config"
    echo "  xbps-smart-service name \"desc\"       # Enable service and add to config"
    echo "  xbps-smart-group groupname            # Add to group and add to config"
    echo "  xbps-smart-repo \"name\" \"url\" [path]  # Add repository and add to config"
    echo "  xbps-smart-restricted package         # Add restricted package to config"
    echo "  xbps-smart-status                     # Show config status"
    echo "  xbps-smart-help                       # Show this help"
}

# Export functions so they're available in the shell
export -f xbps-smart-install xbps-smart-remove xbps-smart-service 
export -f xbps-smart-group xbps-smart-repo xbps-smart-restricted
export -f xbps-smart-status xbps-smart-help

smart_echo "Smart package management aliases loaded!"
smart_echo "Type 'xbps-smart-help' for available commands"
