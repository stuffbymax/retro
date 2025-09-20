#!/bin/sh
# install_all_emulators_manual.sh
# Installs all major emulators and RetroArch with cores on NetBSD using pkgin

echo "Updating pkgin package database..."
sudo pkgin update

echo "Installing PC & DOS emulators..."
sudo pkgin install qemu bochs dosbox 8086tiny tme applyppf

echo "Installing Console emulators..."
sudo pkgin install bsnes snes9x fceux genesis-plus-gx mednafen ppsspp pcsx2 dolphin cygne-sdl basiliskII raine vecx

echo "Installing Home computer emulators..."
sudo pkgin install atari800 aranym arcem xbeeb b-em vice arnold

echo "Installing Arcade & Retro front-end emulators..."
sudo pkgin install advancemame blastem cannonball blinkensim raine emulationstation

echo "Installing RetroArch and all available cores..."
sudo pkgin install retroarch retroarch-cores/*

echo "Upgrading all installed packages to latest versions..."
sudo pkgin upgrade

echo "All emulators, RetroArch, and RetroArch cores have been installed and updated!"
