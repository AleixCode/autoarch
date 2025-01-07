#!/bin/bash -x
echo "[LOG] Something is happening..." >&2


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

pauseForMounting() {
    echo "Please mount EFI partition in /boot/efi. Use tmux if needed."
    echo 'mkdir -p "/boot/efi"'
    echo 'mount "${device}1" "/boot/efi"'
    pause_and_tmux
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


function main() {
    pauseForMounting
    setUpInitramfs
    updatePackageManager
    installDependencies sudo grub efibootmgr dosfstools os-prober mtools kitty firefox
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
}

main
