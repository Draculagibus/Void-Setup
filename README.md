## Void Linux Setup Script

This script automates the installation of Void Linux with custom configurations.

### Download & Run

```bash
git clone https://github.com/Draculagibus/Void-Setup.git
cd Void-Setup/
chmod +x install.sh
./install.sh
```

The dotfiles are symlinked with stow
To make  changes onto the dotfiles it's recommanded to change it here
### How to link the git repo

Generate SSH Key for GitHub/Git Access
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

add the key to your SSH agent:
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Paste the public key from ~/.ssh/id_ed25519.pub to your github account settings

