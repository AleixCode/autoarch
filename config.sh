#!/bin/bash

# Enable strict error handling
set -e  # Exit on any command failure
set -u  # Treat unset variables as an error
set -o pipefail  # Fail if any part of a pipeline fails

# Logging function
log() {
    echo "[LOG] $1"
}

error_exit() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Ensure logs are captured
exec > >(tee -i "$HOME/config.log") 2>&1

function checkIfNotRoot() {
    # Ensure script is not run as root
    if [ "$EUID" -eq 0 ]; then
        error_exit "This script must NOT be run as root."
    fi
}

function installYay() {
    log "Installing Yay AUR helper..."

    # Install dependencies
    sudo pacman -S --noconfirm --needed base-devel git || error_exit "Failed to install base-devel and git"

    # Clone Yay repository
    git clone https://aur.archlinux.org/yay.git || error_exit "Failed to clone yay repository"
    cd yay || error_exit "Failed to enter yay directory"

    # Build and install Yay
    makepkg -si --noconfirm || error_exit "Failed to build and install yay"

    log "Yay installed successfully."
}

function installGraphs() {
    log "Installing graphical environment..."

    cd ~ || error_exit "Failed to switch to home directory"

    # Download RiceInstaller script
    curl -s https://raw.githubusercontent.com/gh0stzk/dotfiles/master/RiceInstaller -o "$HOME/RiceInstaller" || error_exit "Failed to download RiceInstaller"
    chmod +x "$HOME/RiceInstaller" || error_exit "Failed to make RiceInstaller executable"

    # Execute RiceInstaller script
    "$HOME/RiceInstaller" || error_exit "RiceInstaller execution failed"

    # Install display server and desktop environment
    sudo pacman -S --noconfirm --needed xorg sddm || error_exit "Failed to install xorg and sddm"
    sudo pacman -S --noconfirm --needed plasma kde-applications || error_exit "Failed to install Plasma and KDE applications"

    # Enable services
    sudo systemctl enable sddm || error_exit "Failed to enable SDDM"
    sudo systemctl enable NetworkManager || error_exit "Failed to enable NetworkManager"

    log "Graphical environment installed successfully. Rebooting now..."
    sudo systemctl reboot
}

function grubTheme() {
    log "Installing GRUB theme..."

    # Clone GRUB theme repository
    git clone --depth 1 https://gitlab.com/VandalByte/darkmatter-grub-theme.git || error_exit "Failed to clone GRUB theme repository"
    cd darkmatter-grub-theme || error_exit "Failed to enter GRUB theme directory"

    # Install the theme
    sudo python3 darkmatter-theme.py --install || error_exit "Failed to install GRUB theme"

    # Update GRUB configuration
    sudo grub-mkconfig -o /boot/grub/grub.cfg || error_exit "Failed to update GRUB configuration"

    log "GRUB theme installed successfully."
}

function connectToWifi() {
    read -p "Enter SSID: " ssid
    read -s -p "Enter Password: " password
    # Start iwd service
    sudo systemctl start iwd || error_exit "Failed to start iwd service" 
    sudo systemctl enable iwd || error_exit "Failed to start iwd service2" 
    
    # Connect to Wi-Fi
    sudo iwctl station wlan0 connect $ssid --passphrase "$password" || error_exit "Failed to connect to the network" 

    #sudo dhclient wlan0 || error_exit "Failed to get dhcp" 

    # Exit iwd
    exit
}

function main() {
    log "Starting configuration process..."
    connectToWifi

    checkIfNotRoot

    # Create Repos directory
    mkdir -p "$HOME/Repos" || error_exit "Failed to create Repos directory"
    cd "$HOME/Repos" || error_exit "Failed to switch to Repos directory"

    # Install Yay
    installYay

    # Install graphical environment
    installGraphs

    # Set keyboard layout
    log "Setting keyboard layout to 'es'."
    localectl set-keymap es || error_exit "Failed to set keyboard layout"

    # Install GRUB theme
    grubTheme

    log "Configuration completed successfully!"
}

main
