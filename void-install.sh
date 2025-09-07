#!/bin/bash
set -e

# === Clavier ===
loadkeys fr

# === Vérification EFI ===
if [ ! -d /sys/firmware/efi ]; then
    echo "Ce système n'est pas en mode UEFI. Ce script nécessite UEFI."
    exit 1
fi

# === Sélection du disque ===
echo "Disques disponibles :"
lsblk -d -e7 -o NAME,SIZE,MODEL
read -p "Entrez le nom du disque à utiliser (ex: sda, nvme0n1) : " DISK_NAME
DISK="/dev/$DISK_NAME"

# === Saisie des infos utilisateur ===
read -p "Nom d'hôte : " HOSTNAME
read -p "Mot de passe root : " -s ROOT_PASS; echo
read -p "Nom d'utilisateur : " USERNAME
read -p "Mot de passe utilisateur : " -s USER_PASS; echo

# === Partitionnement ===
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 2049MiB
parted -s "$DISK" set 1 boot on
parted -s "$DISK" mkpart primary btrfs 2049MiB 100%

# === Formatage ===
mkfs.vfat -F32 "${DISK}1"
mkfs.btrfs -f "${DISK}2"

# === Sous-volumes BTRFS ===
mount "${DISK}2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

# === Montage final ===
mount -o subvol=@ "${DISK}2" /mnt
mkdir -p /mnt/{boot,home}
mount -o subvol=@home "${DISK}2" /mnt/home
mount "${DISK}1" /mnt/boot

# === Installation du système de base ===
xbps-install -Sy -R https://repo-de.voidlinux.org/current -r /mnt base-system

# === Bind pour chroot ===
for dir in dev proc sys; do mount --bind /$dir /mnt/$dir; done

# === Copie du script post-install dans le système installé ===
cp post-install.sh /mnt/root/post-install.sh
chmod +x /mnt/root/post-install.sh

# === Configuration dans chroot ===
cat <<EOF | chroot /mnt /bin/bash
echo "$HOSTNAME" > /etc/hostname

# Locale
echo "fr_FR.UTF-8 UTF-8" > /etc/default/libc-locales
xbps-reconfigure -f glibc-locales
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf

# Timezone
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime

# Clavier
echo "KEYMAP=fr" > /etc/vconsole.conf

# Réseau
ln -s /etc/sv/dhcpcd /etc/runit/runsvdir/default/

# Utilisateur
echo "root:$ROOT_PASS" | chpasswd
useradd -m -G wheel,audio,video,input -s /bin/bash "$USERNAME"
echo "$USERNAME:$USER_PASS" | chpasswd

# GRUB
xbps-install -y grub-x86_64-efi efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Void
grub-mkconfig -o /boot/grub/grub.cfg

# === Appel du script post-install ===
bash /root/post-install.sh
EOF

echo "✅ Installation terminée. Tu peux maintenant redémarrer."
