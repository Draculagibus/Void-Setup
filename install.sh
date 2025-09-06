#!/bin/bash
set -e

echo "Add custom repository"
echo repository=https://raw.githubusercontent.com/Makrennel/hyprland-void/repository-x86_64-glibc | sudo tee /etc/xbps.d/hyprland-void.conf
sudo xbps-install -S
echo "Custom repository added successfully!"

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
  fish               # Shell
  micro              # Text editor
  starship           # Prompt customizer
  firefox            # Browser
  discord            # Chat app
  steam              # Game launcher
  swww               # Wallpaper
)
sudo xbps-install -Sy "${packages[@]}"
echo "Packages installed successfully!"

echo "Installing Hack Nerd Font..."
TEMP_DIR=$(mktemp -d)
wget -O "$TEMP_DIR/Hack.zip" https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Hack.zip
unzip "$TEMP_DIR/Hack.zip" -d "$TEMP_DIR"
mkdir -p ~/.local/share/fonts
mv "$TEMP_DIR"/*.ttf ~/.local/share/fonts/
fc-cache -fv
rm -rf "$TEMP_DIR"
echo "Hack Nerd Font installed successfully!"


echo "starting services..."
dhcpcd
dbus
seatd
echo "Services started successfully!"

echo "managing user rights..."
sudo usermod -aG _seatd "$USER"
