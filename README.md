## Void Linux Setup Script

This script automates the installation of Void Linux with custom configurations.

### Prerequisites

- A fresh Void Linux installation (glibc)
- Internet connection

### What This Script Does

- Adds custom Hyprland repository
- Enables restricted and multilib packages
- Installs Hyprland, PipeWire, QuickShell, and essential desktop tools
- Builds restricted packages like Discord
- Sets up autologin and Hyprland launch on TTY1
- Installs Bibata cursor theme
- Manages dotfiles with GNU Stow
- Optionally sets up Git and SSH access

### Download & Run

```bash
git clone https://github.com/Draculagibus/Void-Setup.git
cd Void-Setup/
chmod +x install.sh
./install.sh
```
