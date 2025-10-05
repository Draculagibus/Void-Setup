#!/bin/bash
# =============================================================================
# Void Linux Setup Script
# =============================================================================
# Simple, working setup script based on proven approach
# =============================================================================

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"

# Source config files
source "$CONFIG_DIR/repositories.conf"
source "$CONFIG_DIR/packages.conf"
source "$CONFIG_DIR/restricted-packages.conf"
source "$CONFIG_DIR/services.conf"

echo "=== Void Linux Setup ==="
echo

# Add custom repositories
echo "Setting up repositories..."
for repo_config in "${CUSTOM_REPOSITORIES[@]}"; do
    IFS='|' read -r repo_name repo_url repo_conf <<< "$repo_config"
    echo "repository=$repo_url" | sudo tee "$repo_conf" > /dev/null
    echo "Added repository: $repo_name"
done

# Install additional repos
for repo in "${ADDITIONAL_REPOS[@]}"; do
    sudo xbps-install -Sy "$repo"
done
sudo xbps-install -S
echo "Repositories configured!"
echo

# Setup void-packages for restricted packages
echo "Setting up void-packages..."
if [ ! -d "$VOID_PACKAGES_DIR" ]; then
    git clone "$VOID_PACKAGES_REPO" "$VOID_PACKAGES_DIR"
fi
grep -qxF "$XBPS_ALLOW_RESTRICTED" "$VOID_PACKAGES_CONF" || echo "$XBPS_ALLOW_RESTRICTED" >> "$VOID_PACKAGES_CONF"
echo "void-packages ready!"
echo

# Install packages
echo "Installing packages..."
to_install=()
for pkg in "${ALL_PACKAGES[@]}"; do
    if xbps-query -l | grep -qw "$pkg"; then
        echo "$pkg already installed"
    else
        to_install+=("$pkg")
    fi
done

if [ ${#to_install[@]} -gt 0 ]; then
    echo "Installing: ${to_install[*]}"
    sudo xbps-install -Sy "${to_install[@]}"
fi
echo "Packages installed!"
echo

# Build restricted packages
echo "Building restricted packages..."
packages_to_build=("${ALL_RESTRICTED_PACKAGES[@]}")
for pkg in "${packages_to_build[@]}"; do
    if ls "$VOID_PACKAGES_DIR/hostdir/binpkgs" 2>/dev/null | grep -q "^${pkg}-"; then
        echo "$pkg already built"
    else
        echo "Building $pkg..."
        (cd "$VOID_PACKAGES_DIR" && ./xbps-src binary-bootstrap && ./xbps-src pkg "$pkg")
    fi
done
echo "Restricted packages done!"
echo

# Install manual packages
echo "Installing Hyprshot..."
if [ -d "Hyprshot" ]; then
    echo "Hyprshot directory exists, skipping clone"
else
    git clone https://github.com/Gustash/hyprshot.git Hyprshot
fi
chmod +x Hyprshot/hyprshot
sudo rm -rf /usr/local/bin/hyprshot
sudo mv -f Hyprshot/hyprshot /usr/local/bin
rm -rf Hyprshot
echo "Hyprshot installed!"
echo

# Configure PipeWire
echo "Configuring PipeWire..."
WIREPLUMBER_CONF="/etc/pipewire/pipewire.conf.d/10-wireplumber.conf"
if [ ! -L "$WIREPLUMBER_CONF" ]; then
    sudo mkdir -p /etc/pipewire/pipewire.conf.d
    sudo ln -s /usr/share/examples/wireplumber/10-wireplumber.conf "$WIREPLUMBER_CONF"
fi
echo "PipeWire configured!"
echo

# Enable services
echo "Enabling services..."
for svc in "${!SYSTEM_SERVICES[@]}"; do
    if [ -L "/var/service/$svc" ]; then
        echo "$svc already enabled"
    else
        sudo ln -s "/etc/sv/$svc" "/var/service/$svc"
        echo "Enabled $svc"
    fi
done
echo "Services enabled!"
echo

# Add user to groups
echo "Adding user to groups..."
for grp in "${USER_GROUPS[@]}"; do
    if id -nG "$USER" | grep -qw "$grp"; then
        echo "Already in group $grp"
    else
        sudo usermod -aG "$grp" "$USER"
        echo "Added to group $grp"
    fi
done
echo "User groups configured!"
echo

# Install cursor theme
echo "Installing Bibata cursor..."
if [ ! -d "$HOME/.icons/Bibata-Modern-Classic" ]; then
    wget -nc https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Classic.tar.xz
    tar -xf Bibata-Modern-Classic.tar.xz
    mkdir -p ~/.icons/
    mv -f Bibata-Modern-Classic/ ~/.icons/
    rm Bibata-Modern-Classic.tar.xz
fi
echo "Cursor installed!"
echo

# Deploy dotfiles
echo "Deploying dotfiles..."
if [ -d "$SCRIPT_DIR/dotfiles" ]; then
    cd "$SCRIPT_DIR/dotfiles"
    stow --target="$HOME" * 2>/dev/null || echo "Some dotfiles already exist, skipping conflicts"
    cd "$SCRIPT_DIR"
fi
echo "Dotfiles deployed!"
echo

# Create autologin service (don't enable yet)
echo "Creating autologin service..."
sudo mkdir -p "/etc/sv/agetty-autologin-tty1"
sudo tee "/etc/sv/agetty-autologin-tty1/run" > /dev/null <<EOF
#!/bin/sh
exec agetty --autologin $(logname) --noclear tty1 38400 linux
EOF
sudo chmod +x "/etc/sv/agetty-autologin-tty1/run"
echo "Autologin service created (not enabled)"
echo

# Configure Hyprland startup
echo "Configuring Hyprland startup..."
BASH_PROFILE="$HOME/.bash_profile"
touch "$BASH_PROFILE"
if ! grep -q "exec Hyprland" "$BASH_PROFILE"; then
    cat <<'EOF' >> "$BASH_PROFILE"

# Autostart Hyprland on tty1
if [ "$(tty)" = "/dev/tty1" ]; then
    exec Hyprland
fi
EOF
    echo "Hyprland startup configured"
fi
echo

# Setup smart aliases
echo "Setting up smart aliases..."
chmod +x "$SCRIPT_DIR/aliases.sh"
if ! grep -q "void-smart-aliases" "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" <<EOF

# Void setup smart aliases
# void-smart-aliases-marker
if [ -f "$SCRIPT_DIR/aliases.sh" ]; then
    source "$SCRIPT_DIR/aliases.sh"
fi
EOF
    echo "Smart aliases configured"
fi
echo

# Git/SSH setup
read -p "Do you want to set up Git and SSH? (y/n): " use_git
if [[ "$use_git" =~ ^[Yy]$ ]]; then
    key_path="$HOME/.ssh/id_ed25519"
    if [ ! -f "$key_path" ]; then
        read -p "Generate SSH key? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            read -p "Enter your email: " email
            ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""
            eval "$(ssh-agent -s)"
            ssh-add "$key_path"
            if command -v wl-copy &>/dev/null; then
                wl-copy < "$key_path.pub"
                echo "Public key copied to clipboard"
            else
                cat "$key_path.pub"
            fi
            echo "Add to GitHub: https://github.com/settings/keys"
        fi
    fi
fi
echo

echo "=== Setup Complete! ==="
echo
echo "To enable autologin:"
echo "  sudo rm /var/service/agetty-tty1"
echo "  sudo ln -s /etc/sv/agetty-autologin-tty1 /var/service/"
echo "  sudo reboot"
echo

read -rp "Reboot now? [y/N] " answer
case "$answer" in
    [Yy]* ) sudo reboot ;;
    * ) echo "Reboot when ready!" ;;
esac
