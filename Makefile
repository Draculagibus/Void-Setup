# =============================================================================
# Hyprland Environment Setup Makefile
# =============================================================================
# Provides convenient commands for installation and management

.PHONY: help install update clean check-deps validate test-modules

# Default target
help:
	@echo "Hyprland Environment Setup"
	@echo "=========================="
	@echo ""
	@echo "Available targets:"
	@echo "  install      - Run the full installation"
	@echo "  update       - Update repositories and re-run installation"
	@echo "  clean        - Clean up temporary files"
	@echo "  check-deps   - Check system dependencies"
	@echo "  validate     - Validate configuration files"
	@echo "  test-modules - Test module syntax"
	@echo "  backup       - Create backup of current system state"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Usage: make <target>"

# Main installation target
install: check-deps validate
	@echo "Starting Hyprland environment installation..."
	./install.sh

# Update and re-install
update: clean
	@echo "Updating repositories and re-installing..."
	git pull 2>/dev/null || true
	./install.sh

# Clean up temporary files
clean:
	@echo "Cleaning up temporary files..."
	rm -rf tmp/
	rm -f *.log
	@echo "Cleanup completed"

# Check system dependencies
check-deps:
	@echo "Checking system dependencies..."
	@command -v sudo >/dev/null 2>&1 || { echo "Error: sudo is required"; exit 1; }
	@command -v git >/dev/null 2>&1 || { echo "Error: git is required"; exit 1; }
	@command -v xbps-install >/dev/null 2>&1 || { echo "Error: This script is for Void Linux only"; exit 1; }
	@command -v stow >/dev/null 2>&1 || { echo "Warning: stow not found, will be installed"; }
	@echo "Dependencies check passed"

# Validate configuration files
validate:
	@echo "Validating configuration files..."
	@test -f config/repositories.conf || { echo "Error: config/repositories.conf missing"; exit 1; }
	@test -f config/packages.conf || { echo "Error: config/packages.conf missing"; exit 1; }
	@test -f config/restricted-packages.conf || { echo "Error: config/restricted-packages.conf missing"; exit 1; }
	@test -f config/services.conf || { echo "Error: config/services.conf missing"; exit 1; }
	@echo "Configuration validation passed"

# Test module syntax
test-modules:
	@echo "Testing module syntax..."
	@for module in modules/*.sh; do \
		echo "Testing $$module..."; \
		bash -n "$$module" || exit 1; \
	done
	@bash -n install.sh || exit 1
	@echo "All modules passed syntax check"

# Create system backup
backup:
	@echo "Creating system backup..."
	@backup_dir="backup-$$(date +%Y%m%d-%H%M%S)"; \
	mkdir -p "$$backup_dir"; \
	cp -r ~/.config "$$backup_dir/config-backup" 2>/dev/null || true; \
	cp ~/.bashrc "$$backup_dir/bashrc-backup" 2>/dev/null || true; \
	cp ~/.bash_profile "$$backup_dir/bash_profile-backup" 2>/dev/null || true; \
	echo "Backup created in $$backup_dir"

# Development targets
dev-setup:
	@echo "Setting up development environment..."
	chmod +x install.sh
	chmod +x modules/*.sh

# Lint shell scripts
lint:
	@echo "Linting shell scripts..."
	@command -v shellcheck >/dev/null 2>&1 || { echo "Warning: shellcheck not found"; exit 0; }
	shellcheck install.sh modules/*.sh

# Show system information
info:
	@echo "System Information:"
	@echo "==================="
	@echo "OS: $$(uname -s)"
	@echo "Kernel: $$(uname -r)"
	@echo "Architecture: $$(uname -m)"
	@echo "User: $$USER"
	@echo "Home: $$HOME"
	@echo "Shell: $$SHELL"
	@echo ""
	@echo "Void Linux Information:"
	@xbps-query -l | wc -l | xargs echo "Installed packages:"
	@echo "XBPS version: $$(xbps-query -v 2>/dev/null | head -1 || echo 'Unknown')"
