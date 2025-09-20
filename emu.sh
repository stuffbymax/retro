#!/bin/sh
# install_all_emulators.sh
# Installs/updates all emulators, RetroArch, and all RetroArch cores on NetBSD

PKGSRC_DIR="/usr/pkgsrc"   # Adjust if pkgsrc is elsewhere

# Step 1: Update pkgsrc tree
echo "Updating pkgsrc..."
cd "$PKGSRC_DIR" || exit 1
sudo cvs -q up -dP  # or `git pull` if using pkgsrc-git

# Step 2: Install or update all emulators
echo "Installing/updating all emulators..."
for emulator_dir in "$PKGSRC_DIR"/emulators/*; do
    if [ -d "$emulator_dir" ]; then
        echo "Installing/updating $(basename "$emulator_dir")..."
        cd "$emulator_dir" || continue
        sudo make install clean
    fi
done

# Step 3: Install or update RetroArch
if [ -d "$PKGSRC_DIR/emulators/retroarch" ]; then
    echo "Installing/updating RetroArch..."
    cd "$PKGSRC_DIR/emulators/retroarch" || exit 1
    sudo make install clean
fi

# Step 4: Install or update all RetroArch cores
if [ -d "$PKGSRC_DIR/emulators/retroarch-cores" ]; then
    echo "Installing/updating all RetroArch cores..."
    for core_dir in "$PKGSRC_DIR"/emulators/retroarch-cores/*; do
        if [ -d "$core_dir" ]; then
            echo "Installing/updating $(basename "$core_dir")..."
            cd "$core_dir" || continue
            sudo make install clean
        fi
    done
fi

# Step 5: Update all installed packages via pkgin
echo "Updating all installed packages..."
sudo pkgin update
sudo pkgin upgrade

echo "All emulators, RetroArch, and RetroArch cores are installed and up to date!"
