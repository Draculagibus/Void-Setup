#!/bin/bash
set -e

echo "installing packages..."
sudo xbps-install -Sy \
ntp \
