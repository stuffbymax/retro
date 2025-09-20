#!/bin/sh
# install_all_emulators_pkgin.sh
# Installs/updates all available emulators, RetroArch, and all RetroArch cores using pkgin

echo "Updating pkgin package database..."
sudo pkgin update

echo "Installing/updating all available emulators..."
# Install all packages under 'emulators' category
sudo pkgin install -y emulators/*

echo "Installing/updating RetroArch and all cores..."
sudo pkgin install -y emulators/retroarch emulators/retroarch-cores/*

echo "Upgrading all installed packages to the latest version..."
sudo pkgin upgrade -y

echo "All emulators, RetroArch, and RetroArch cores are installed and up to date!"
