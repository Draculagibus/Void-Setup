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

echo "Expand the repos..."
  sudo xbps-install -Sy void-repo-multilib # Add multilib repos 
  sudo xbps-install -Sy void-repo-nonfree  # Add nonfree repos
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
  pipewire           # Sound management
  pavucontrol        # Volume control
  bluez              # Bluetooth management
  xdg-desktop-portal-hyprland # Window Manager
  hyprland           # Window Manager
  hyprpaper          # Wallpaper Manager
  hyprlock           # LockScreen Manager
  hyprland-qtutils   # Qt/QML utility for Hyprland
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
  jq                 # Dependencie for Hyprshot
  libnotify          # Dependencie for Hyprshot
)
to_install=()
for pkg in "${packages[@]}"; do
  if xbps-query -l | grep -qw "$pkg"; then
    echo "$pkg is already installed"
  else
    to_install+=("$pkg")
  fi
done

if [ ${#to_install[@]} -gt 0 ]; then
  echo "Installing missing packages: ${to_install[*]}"
  sudo xbps-install -Sy "${to_install[@]}"
else
  echo "All packages are already installed"
fi

echo "Packages installed successfully!"

echo "Installing restricted packages..."
restricted_packages=(
  discord                # Chat / Vocal servers
)
for pkg in "${restricted_packages[@]}"; do
  if ls ~/void-packages/hostdir/binpkgs | grep -q "^${pkg}-"; then
    echo "$pkg already built"
  else
    ~/void-packages/xbps-src pkg "$pkg"
  fi
done
echo "Restricted packages installed successfully!"

echo "Installing some packages manually"
git clone https://github.com/Gustash/hyprshot.git Hyprshot
mkdir -p ~/.local/bin
ln -s $(pwd)/Hyprshot/hyprshot $HOME/.local/bin
chmod +x Hyprshot/hyprshot
echo "Packages installed..."

echo "Configuring PipeWire..."
WIREPLUMBER_CONF="/etc/pipewire/pipewire.conf.d/10-wireplumber.conf"
if [ -L "$WIREPLUMBER_CONF" ]; then
  echo "WirePlumber config already linked"
else
  sudo mkdir -p /etc/pipewire/pipewire.conf.d
  sudo ln -s /usr/share/examples/wireplumber/10-wireplumber.conf "$WIREPLUMBER_CONF"
  echo "WirePlumber config linked"
fi
echo "PipeWire configuration Success!"

echo "Starting services..."

declare -A services=(
  [dhcpcd]="Network configuration via DHCP"
  [dbus]="Session and system message bus"
  [seatd]="Seat management for Wayland compositors"
  [ntpd]="Time synchronization daemon"
  [pipewire]="Audio and video server"
  [bluetoothd]="Bluetooth device management"
  [sshd]="Secure shell server for remote access"
  [acpid]="ACPI event daemon for power management"
)

for svc in "${!services[@]}"; do
  if [ -L "/var/service/$svc" ]; then
    echo "Service '$svc' already enabled — ${services[$svc]}"
  else
    sudo ln -s "/etc/sv/$svc" "/var/service/$svc"
    echo "Enabled service '$svc' — ${services[$svc]}"
  fi
done
echo "Services started successfully!"

echo "Managing user rights..."
groups_to_add=(_seatd audio video input wheel)
for grp in "${groups_to_add[@]}"; do
  if id -nG "$USER" | grep -qw "$grp"; then
    echo "User '$USER' is already in group '$grp'"
  else
    sudo usermod -aG "$grp" "$USER"
    echo "Added user '$USER' to group '$grp'"
  fi
done
echo "User rights added!"

