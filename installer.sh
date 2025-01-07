#!/bin/bash

set -e  # Exit immediately if a command fails
set -u  # Treat unset variables as an error
set -o pipefail  # Fail pipeline if any command fails

log() {
    echo "[LOG] $1"
}

error_exit() {
    echo "[ERROR] $1" >&2
    exit 1
}

function InstallPackage() {
   log "Installing package: $1"
   pacman -S --noconfirm --needed "$1" || error_exit "Failed to install $1"
}

function setUpKeyboard() {
   log "Setting up keyboard layout"
   loadkeys es || error_exit "Failed to set keyboard layout"
}

function updateDependences() {
   log "Updating dependencies"
   pacman -Sy || error_exit "Failed to synchronize package database"
   InstallPackage "efibootmgr"
}

pauseForPartitioning() {
    while true; do
        echo "Please partition and mount your drives manually. Use tmux to manage sessions if needed."
        echo "Tmux commands:
 - Start a new session: Ctrl-b then c
 - Switch sessions: Ctrl-b then s
 - Detach session: Ctrl-b then d
 - Reattach session: tmux attach-session -t <session-name>"
        read -p "Press Enter to continue only after completing partitioning and mounting..." input
        [[ -z "$input" ]] && break
    done
}

generateFstab() {
   log "Generating fstab"
   mkdir -p "/mnt/etc"
   genfstab -U "/mnt" >> "/mnt/etc/fstab" || error_exit "Failed to generate fstab"
}

installPackman() {
    log "Installing and configuring pacman"
    if [ ! -e "/mnt/etc/pacman.conf" ]; then
        cp -f "/etc/pacman.conf" "/mnt/etc/pacman.conf" || error_exit "Failed to copy pacman.conf"
    fi
    sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist || error_exit "Failed to configure mirrors"
}

installEssentials() {
   log "Installing essential packages"
   pacstrap /mnt linux linux-headers linux-firmware base networkmanager grub wpa_supplicant base base-devel || error_exit "Failed to install essential packages"
}

pauseForMounting() {
    while true; do
        echo "Please mount EFI partition in /boot/EFI. Use tmux if needed."
        read -p "Press Enter to continue only after mounting..." input
        [[ -z "$input" ]] && break
    done
}

setUpInitramfs() {
   log "Setting up initramfs"
   mkinitcpio -P || error_exit "Failed to generate initramfs"
}

updatePackageManager() {
    log "Updating package manager"
    pacman -Syu || error_exit "Failed to update package manager"
}

installDependencies() {
    log "Installing dependencies"
    for pkg in "$@"; do
        InstallPackage "$pkg"
    done
}

setTimeZone() {
   log "Setting up timezone"
   ln -sf "/usr/share/zoneinfo/Europe/Madrid" "/etc/localtime" || error_exit "Failed to set timezone"
}

setUpHostname() {
   log "Setting up hostname"
   echo "theMachine" > "/etc/hostname"
}

setUpLanguage() {
   log "Setting up language"
   echo "LANG=en_US.UTF-8" > "/etc/locale.conf"
}

setUpKeyboardLayout() {
   log "Setting up keyboard layout"
   sed -i '/en_US.UTF-8 UTF-8/s/^#//' "/etc/locale.gen" || error_exit "Failed to configure locale"
   sed -i '/es_ES.UTF-8 UTF-8/s/^#//' "/etc/locale.gen"
   locale-gen || error_exit "Failed to generate locale"
   echo "KEYMAP=es" > "/etc/vconsole.conf"
}

installAndSetUpSudo() {
   log "Setting up sudo"
   cp /etc/sudoers /tmp/sudoers.tmp || error_exit "Failed to copy sudoers file"
   grep -qxF '%wheel ALL=(ALL:ALL) ALL' /tmp/sudoers.tmp || echo "%wheel ALL=(ALL:ALL) ALL" >> /tmp/sudoers.tmp
   visudo -c -f /tmp/sudoers.tmp || error_exit "Invalid sudoers configuration"
   cp /tmp/sudoers.tmp /etc/sudoers || error_exit "Failed to replace sudoers file"
}

setUpRoot() {
   log "Setting up root password"
   passwd || error_exit "Failed to set root password"
}

createUser() {
   log "Creating user $1"
   useradd -m -G wheel "$1" || error_exit "Failed to create user $1"
   passwd "$1" || error_exit "Failed to set password for $1"
}

setUpUsers() {
   while true; do
      read -p "Create a new User? [Y/n]: " answer
      [[ "$answer" =~ ^[nN]$ ]] && break
      read -p "Enter username: " name
      createUser "$name"
   done
}

setUpGRUB() {
   log "Setting up GRUB"
   InstallPackage grub efibootmgr dosfstools os-prober mtools
   grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck || error_exit "Failed to install GRUB"
   grub-mkconfig -o /boot/grub/grub.cfg || error_exit "Failed to generate GRUB config"
}

setUpNetwork() {
   log "Setting up network"
   systemctl enable --now NetworkManager || error_exit "Failed to enable NetworkManager"
}

updateSystemFiles() {
    updatedb || error_exit "Failed to update system files"
}

main() {
    setUpKeyboard
    updateDependences

    pauseForPartitioning

    pacman-key --init || error_exit "Failed to initialize pacman keyring"
    pacman-key --populate || error_exit "Failed to populate keyring"

    generateFstab
    installPackman
    installEssentials

    arch-chroot /mnt <<EOF
    pauseForMounting
    setUpInitramfs
    updatePackageManager
    installDependencies sudo visudo grub efibootmgr dosfstools os-prober mtools kitty firefox
    setTimeZone
    setUpHostname
    setUpLanguage
    setUpKeyboardLayout
    installAndSetUpSudo
    setUpRoot
    setUpUsers
    setUpGRUB
    setUpNetwork
    updateSystemFiles
EOF
}

main
