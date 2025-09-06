#!/bin/bash
set -e

MNT="/"  # Change to your Btrfs mount point
DATE=$(date +%Y-%m-%d_%H-%M-%S)

echo "Creating read-only snapshots..."
sudo btrfs subvolume snapshot -r "$MNT/@ " "$MNT/@_snap_$DATE"
sudo btrfs subvolume snapshot -r "$MNT/@home" "$MNT/@home_snap_$DATE"

echo "Snapshots created for $DATE"
