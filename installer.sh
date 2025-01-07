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


function pause_and_tmux() {
    echo "Press Enter to continue..."
    read -r

    # Create a new tmux session and attach to it
    tmux new-session -d -s my_session
    tmux attach-session -t my_session

    # Wait for the user to finish their work in the tmux session
    while tmux has-session -t my_session 2>/dev/null; do
        sleep 1
    done

    # After the tmux session is closed, ask for input in the main terminal
    echo "Please enter your input to continue: "
    read -r user_input
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
    echo "Please partition and mount your drives manually. Use tmux to manage sessions if needed."
    pause_and_tmux
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

enterArch() {
    curl -Lo /mnt/archroot.sh https://raw.githubusercontent.com/AleixCode/autoarch/refs/heads/main/archroot.sh
    curl -Lo /mnt/config.sh https://raw.githubusercontent.com/AleixCode/autoarch/refs/heads/main/config.sh
    chmod +x /mnt/archroot.sh /mnt/config.sh 
    arch-chroot /mnt /archroot.sh
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

    enterArch
}

main
