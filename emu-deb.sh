#!/bin/bash
# install_all_emulators_debian_nobackslash.sh
# Debian emulator installer with automatic yes, no line continuations

echo "Choose installation method:"
echo "1) Install prebuilt packages (apt)"
echo "2) Compile from source (manual)"
read -p "Enter 1 or 2: " method

if [ "$method" = "1" ]; then
    echo "Updating package list..."
    sudo apt update

    echo "Installing PC & DOS emulators..."
    sudo apt install -y qemu
    sudo apt install -y bochs
    sudo apt install -y dosbox
    sudo apt install -y bsnes
    sudo apt install -y snes9x
    sudo apt install -y fceux
    sudo apt install -y genesis-plus-gx
    sudo apt install -y mednafen
    sudo apt install -y ppsspp
    sudo apt install -y pcsx2
    sudo apt install -y dolphin
    sudo apt install -y atari800
    sudo apt install -y aranym
    sudo apt install -y arcem
    sudo apt install -y b-em
    sudo apt install -y vice
    sudo apt install -y arnold
    sudo apt install -y advancemame
    sudo apt install -y blastem
    sudo apt install -y cannonball
    sudo apt install -y emulationstation
    sudo apt install -y retroarch

    echo "All emulators and RetroArch installed via apt."

elif [ "$method" = "2" ]; then
    echo "Compiling emulators from source..."

    SRC_DIR="$HOME/src_emulators"
    mkdir -p "$SRC_DIR"
    cd "$SRC_DIR" || exit 1

    echo "Compiling DOSBox..."
    if [ ! -d "dosbox" ]; then
        git clone https://github.com/dosbox-staging/dosbox-staging.git dosbox
    fi
    cd dosbox || exit
    ./autogen.sh
    ./configure
    make
    sudo make install
    cd "$SRC_DIR"

    echo "Compiling RetroArch..."
    if [ ! -d "retroarch" ]; then
        git clone https://github.com/libretro/RetroArch.git retroarch
    fi
    cd retroarch || exit
    ./configure
    make
    sudo make install

    echo "Repeat compilation steps for other emulators as needed."

else
    echo "Invalid choice. Exiting."
    exit 1
fi

echo "All selected emulators and RetroArch setup complete!"
