#!/bin/bash
set -e

echo "Add custom repository..."
echo repository=https://raw.githubusercontent.com/Makrennel/hyprland-void/repository-x86_64-glibc | sudo tee /etc/xbps.d/hyprland-void.conf
sudo xbps-install -S
echo "Custom repository added successfully!"

echo "Allow restricted packages..."
# Check if the directory already exists
if [ -d "$HOME/void-packages" ]; then
    echo "Repository already cloned at ~/void-packages"
else
    git clone https://github.com/void-linux/void-packages.git ~/void-packages
    echo "Cloned void-packages repository"
fi
grep -qxF 'XBPS_ALLOW_RESTRICTED=yes' ~/void-packages/etc/conf || echo 'XBPS_ALLOW_RESTRICTED=yes' >> ~/void-packages/etc/conf
echo "Allowed restricted packages successfully"

echo "Expend the repos..."
  void-repo-multilib # Add multilib repos 
  void-repo-nonfree  # Add nonfree repos
echo "repos extended successfully"

echo "Installing packages..."
packages=(
  ntp                # time sync
  dbus               # session bus
  seatd              # seat management
  dumb_runtime_dir   # XDG_RUNTIME_DIR handler
  mesa-dri           # OpenGL support
  mesa-vulkan-radeon # Vulkan support
  mesa-vaapi         # Video acceleration
  mesa-vdpau         # Video acceleration
  wget               # Download stuff on the web
  unzip              # Manage zip files
  pipewire           # Sound managment
  pavucontrol        # Volume control
  bluez              # Bluetooth managment
  xdg-desktop-portal-hyprland # Window Manager
  hyprland           # Window Manager
  quickshell         # Desktop shell toolkit
  wl-clipboard       # To copy screenshots to clipboard
  cliphist           # Manage clipboard & Screenshot
  grim               # Takes screenshots of the screen or regions
  slurp              # Select a region with your mouse
  dolphin            # File explorer
  kitty              # Terminal
  fish-shell         # Shell
  micro              # Text editor
  starship           # Prompt customizer
  firefox            # Browser
  steam              # Game launcher
  swww               # Wallpaper
  grub-btrfs         # Manage BTRFS snapshots from GRUB
  btrfs-progs        # BTRFS Commands
)
sudo xbps-install -Sy "${packages[@]}"
echo "Packages installed successfully!"

echo "Installing restricted packages..."
restricted_packages=(
  Discord                # Chat / Vocal servers
)
~/void-packages/xbps-src pkg "${restricted_packages[@]}"
echo "Restricted packages installed successfully!"

echo "Make PipeWire run WirePlumber directly..."
mkdir -p /etc/pipewire/pipewire.conf.d
ln -s /usr/share/examples/wireplumber/10-wireplumber.conf /etc/pipewire/pipewire.conf.d/
echo "PipeWireSuccess!"

echo "starting services..."
sudo ln -s /etc/sv/dhcpcd /var/service
sudo ln -s /etc/sv/dbus /var/service
sudo ln -s /etc/sv/seatd /var/service
sudo ln -s /etc/sv/ntpd /var/service
sudo ln -s /etc/sv/pipewire /var/service
sudo ln -s /etc/sv/bluetoothd /var/service
sudo ln -s /etc/sv/sshd /var/service
sudo ln -s /etc/sv/acpid /var/service
echo "Services started successfully!"

echo "managing user rights..."
sudo usermod -aG _seatd "$USER"

# Need to check if zzz is installed by default

