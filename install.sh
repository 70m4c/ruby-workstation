#!/usr/bin/env bash

#
# Ruby Workstation
#
# https://github.com/70m4c/ruby-workstation
#

################################################################################
# Copyright ©2021 Томас
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <https://www.gnu.org/licenses/gpl-3.0.html>.
################################################################################

################################################################################
# START OF VARIABLES SECTION
# EDIT THE FOLLOWING VARIABLES TO FIT YOUR SPECIFIC SETUP

USERNAME="user"
ADDL_USERGROUPS="wheel,storage,docker"
USER_SHELL="/bin/bash"
KEYMAP="us"
CONSOLE_FONT="ter-128n"
INSTALL_DEVICE="/dev/sda"
NETWORK_INTERFACE="enp0s3"
HOSTNAME="ruby-dev"
IP_ADDRESS="127.0.1.1"
LOCALE="en_US.UTF-8"
TIMEZONE="America/Chicago"
NTP_SERVERS="time1.facebook.com time2.facebook.com time3.facebook.com time4.facebook.com time5.facebook.com"
NTP_FALLBACK_SERVERS="time1.google.com time2.google.com time3.google.com time4.google.com"
SERVICES="systemd-networkd systemd-resolved systemd-timesyncd lightdm docker"

# END OF VARIABLES SECTION
# DO NOT EDIT BELOW THIS LINE UNLESS YOU KNOW WHAT YOU'RE DOING!
################################################################################

# Log introduction
echo ""
echo "--------------------------------------------------------------------------------"
echo "--------------------------- NEW INSTALLATION STARTED ---------------------------"
echo "--------------------------------------------------------------------------------"
echo "Current Date & Time: $(TZ=${TIMEZONE} date)"
echo "Variables"
echo "---------"
echo "USERNAME: ${USERNAME}"
echo "ADDL_USERGROUPS: ${ADDL_USERGROUPS}"
echo "USER_SHELL: ${USER_SHELL}"
echo "KEYMAP: ${KEYMAP}"
echo "CONSOLE_FONT: ${CONSOLE_FONT}"
echo "INSTALL_DEVICE: ${INSTALL_DEVICE}"
echo "NETWORK_INTERFACE: ${NETWORK_INTERFACE}"
echo "HOSTNAME: ${HOSTNAME}"
echo "IP_ADDRESS: ${IP_ADDRESS}"
echo "LOCALE: ${LOCALE}"
echo "TIMEZONE: ${TIMEZONE}"
echo "NTP_SERVERS: ${NTP_SERVERS}"
echo "NTP_FALLBACK_SERVERS: ${NTP_FALLBACK_SERVERS}"
echo "SERVICES: ${SERVICES}"
echo "--------------------------------------------------------------------------------"

# Installer keymap
echo "Setting keyboard layout"
loadkeys ${KEYMAP}

# Console font
echo "Setting the console font"
setfont ${CONSOLE_FONT}

# Ensure EFI
echo "Making sure the system is booted in EFI mode by checking for /sys/firmware/efi/efivars"
if [ ! -d "/sys/firmware/efi/efivars" ]; then
  echo "ERROR: It doesn't seem we're booted in EFI mode"
  exit 1
fi

# Password
echo "Asking the user '${USERNAME}' for a password"
USER_PASSWORD=""
until [ -n "${USER_PASSWORD}" ]
do
  read -s -r -p "Enter a password for the user '${USERNAME}': " firstpassword </dev/tty
  echo ""
  read -s -r -p "Again: " secondpassword </dev/tty
  echo ""

  if [ -n "${firstpassword}" ]; then
    if [ "${firstpassword}" == "${secondpassword}" ]; then
      USER_PASSWORD=${firstpassword}
    else
      echo "ERROR: Those passwords don't match"
    fi
  else
    echo "ERROR: You must enter a password to continue"
  fi
done
echo "A password has been set."

# Time sync
echo "Activating and enabling time sync on the booted system"
timedatectl set-ntp true

# Partitions
echo "Creating a GPT partition table on ${INSTALL_DEVICE}"
parted -s ${INSTALL_DEVICE} mklabel gpt
echo "Creating a 512MB ESP boot partition on ${INSTALL_DEVICE}"
parted -s ${INSTALL_DEVICE} mkpart ESP fat32 0% 513MiB
echo "Creating a Linux system partition using the remaining disk space on ${INSTALL_DEVICE}"
parted -s ${INSTALL_DEVICE} mkpart ROOT ext4 513MiB 100%
echo "Setting the boot flag to the ESP parition on ${INSTALL_DEVICE}"
parted -s ${INSTALL_DEVICE} set 1 esp on

# File systems
echo "Creating a FAT32 file system on ${INSTALL_DEVICE}1"
mkfs.fat -n ESP -F32 ${INSTALL_DEVICE}1
echo "Creating an EXT4 file system on ${INSTALL_DEVICE}2"
mkfs.ext4 ${INSTALL_DEVICE}2

# Mount devices
echo "Mounting ${INSTALL_DEVICE}2 to /mnt"
mount ${INSTALL_DEVICE}2 /mnt
echo "Creating a /mnt/boot directory"
mkdir /mnt/boot
echo "Mounting ${INSTALL_DEVICE}1 to /mnt/boot"
mount ${INSTALL_DEVICE}1 /mnt/boot

# Installer mirrorlist
echo "Removing the existing boot system mirror list from /etc/pacman.d/mirrorlist"
rm /etc/pacman.d/mirrorlist
echo "Copying your configured mirror list to /etc/pacman.d/mirrorlist"
cp mirrorlist /etc/pacman.d/mirrorlist

# Update keyring
echo "Force refresh of all package databases"
pacman --sync --refresh --refresh 
echo "Update the Pacman keyring in case some package maintainers in the ISO have expired"
pacman --sync --noconfirm archlinux-keyring

# Packages installation
echo -e "Installing packages to /mnt:\n$(<packages)"
pacstrap /mnt $(<packages)

# Create user account
echo "Creating user '${USERNAME}', with additional groups [${ADDL_USERGROUPS}], and shell ${USER_SHELL}"
arch-chroot /mnt useradd -m -G ${ADDL_USERGROUPS} -s ${USER_SHELL} ${USERNAME}

# Set password
echo "Setting the user password"
printf "%s\n%s" "${USER_PASSWORD}" "${USER_PASSWORD}" | arch-chroot /mnt passwd ${USERNAME}

# Enable wheel group to sudo
echo "Enable wheel group to perform sudo commands"
echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel

# Copy files to new system
echo "Copying files to the new system"
cp -rf ./files/etc/. /mnt/etc
cp -rf ./files/home/user/. /mnt/home/${USERNAME}
arch-chroot /mnt chown -R ${USERNAME}:${USERNAME} /mnt/home/${USERNAME}

# Generate fstab
echo "Generating fstab file from mounted devices and placing in /mnt/etc/fstab"
genfstab -U /mnt >> /mnt/etc/fstab

# Set the timezone and time server(s)
echo "Setting the time zone to: ${TIMEZONE}"
arch-chroot /mnt ln --symbolic --force /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

# NTP Servers
echo "Set NTP servers to: ${NTP_SERVERS}"
sed -i "s/#NTP=.*/NTP=${NTP_SERVERS}/" /mnt/etc/systemd/timesyncd.conf
echo "Set NTP fallback servers to: ${NTP_FALLBACK_SERVERS}"
sed -i "s/#FallbackNTP=.*/FallbackNTP=${NTP_FALLBACK_SERVERS}/" /mnt/etc/systemd/timesyncd.conf

# Enable time sync
echo "Enable and start systemd-timesyncd"
arch-chroot /mnt timedatectl set-ntp true

# Generate /etc/adjtime
echo "Running hwclock to generate /etc/adjtime"
arch-chroot /mnt hwclock --systohc

# Set locale
echo "Enabling the locale: ${LOCALE}"
sed -i "/^#${LOCALE}/s/^#//g" /mnt/etc/locale.gen

# Generate Locale data
echo "Generate locale data for: ${LOCALE}"
arch-chroot /mnt locale-gen

# Set LANG
echo "Set LANG environment variable to: ${LOCALE}"
echo "LANG=${LOCALE}" >> /mnt/etc/locale.conf

# Set keymap
echo "Set the keyboard layout to: ${KEYMAP}"
echo "KEYMAP=${KEYMAP}" >> /mnt/etc/vconsole.conf

# Configure systemd-networkd
echo "Configure systemd-networkd"
{
  echo "[Match]"
  echo "Name=${NETWORK_INTERFACE}"
  echo ""
  echo "[Network]"
  echo "DHCP=yes"
} > /mnt/etc/systemd/network/20-wired.network

# Set hostname
echo "Set the hostname to: ${HOSTNAME}"
echo ${HOSTNAME} > /mnt/etc/hostname

# Set hosts file
echo "Creating hosts file"
{
  echo "127.0.0.1 localhost"
  echo "::1 localhost"
  echo "${IP_ADDRESS} ${HOSTNAME}"
} > /mnt/etc/hosts

# Add 70m4c repo
echo "Adding 70m4c repo"
{
  echo ""
  echo "[70m4c]"
  echo "Server = http://mirror.70m4c.su/70m4c/aur-repo/\$arch"
  echo "SigLevel = Optional TrustAll"
} >> /mnt/etc/pacman.conf

# Configure GRUB boot loader
echo "Install GRUB"
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
echo "Generate grub.cfg"
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Enable services
echo "Enabling services: ${SERVICES}"
arch-chroot /mnt systemctl enable ${SERVICES}