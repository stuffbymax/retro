#!/bin/bash
# Arch Emulator + Minimal Desktop + XFCE4 Installer (Intel, RetroArch-git via yay)
# Fully automated setup using default RetroArch config
set -e

echo "Starting full automated setup..."

# 1. Update system
sudo pacman -Syu --noconfirm

# 2. Install essential packages
sudo pacman -S --noconfirm base-devel git jwm icewm xfce4 xfce4-goodies xorg-server xorg-xinit xorg-xinput mesa vulkan-intel vulkan-icd-loader antimicrox

# 3. Install yay (if not installed)
if ! command -v yay >/dev/null 2>&1; then
    echo "Installing yay..."
    TMP_YAY="/tmp/yay"
    git clone https://aur.archlinux.org/yay.git "$TMP_YAY"
    cd "$TMP_YAY"
    makepkg -si --noconfirm
    cd ~
    rm -rf "$TMP_YAY"
fi

# 4. Install RetroArch-git via yay
yay -S --noconfirm retroarch-git

# 5. Setup default JWM config
mkdir -p ~/.jwm
cp -r /etc/xdg/jwm/* ~/.jwm/

# 6. Setup default IceWM config
mkdir -p ~/.icewm
cp -r /etc/icewm/* ~/.icewm/

# 7. Create emulator → desktop shell script
START_SCRIPT="$HOME/start_emulator_then_desktop.sh"
cat > "$START_SCRIPT" <<'EOL'
#!/bin/bash
export DISPLAY=${DISPLAY:-:0}

# Start RetroArch-git fullscreen using default config
retroarch --fullscreen

# RetroArch exited
# Start GUI gamepad mapper in background
command -v antimicrox >/dev/null 2>&1 && antimicrox &

# Launch minimal desktop (JWM by default)
exec jwm
EOL

chmod +x "$START_SCRIPT"

# 8. Setup .xinitrc to auto-start emulator script
XINIT_FILE="$HOME/.xinitrc"
echo "exec $START_SCRIPT" > "$XINIT_FILE"

# 9. Generate dynamic JWM menu
JWM_MENU="$HOME/.jwm/menu.xml"
cat > "$JWM_MENU" <<EOL
<Root>
    <Menu label="Applications">
EOL

for file in /usr/share/applications/*.desktop; do
    name=$(grep -m1 '^Name=' "$file" | cut -d= -f2- | sed 's/&/&amp;/g')
    exec_cmd=$(grep -m1 '^Exec=' "$file" | cut -d= -f2- | sed 's/%.//g' | sed 's/&/&amp;/g')
    if [[ -n "$name" && -n "$exec_cmd" ]]; then
        echo "        <Program label=\"$name\" icon=\"\">$exec_cmd</Program>" >> "$JWM_MENU"
    fi
done

cat >> "$JWM_MENU" <<EOL
    </Menu>
</Root>
EOL

# 10. Generate dynamic IceWM menu
ICEWM_MENU="$HOME/.icewm/menu"
echo "\"Applications\" {" > "$ICEWM_MENU"

for file in /usr/share/applications/*.desktop; do
    name=$(grep -m1 '^Name=' "$file" | cut -d= -f2-)
    exec_cmd=$(grep -m1 '^Exec=' "$file" | cut -d= -f2- | sed 's/%.//g')
    if [[ -n "$name" && -n "$exec_cmd" ]]; then
        echo "    \"$name\" \"$exec_cmd\"" >> "$ICEWM_MENU"
    fi
done

echo "}" >> "$ICEWM_MENU"

# 11. Inform user
echo "--------------------------------------------------"
echo "Setup complete!"
echo "Reboot your system."
echo "It will boot straight into RetroArch-git fullscreen (default config) via startx."
echo "Exit RetroArch to start the minimal desktop (JWM) with GUI gamepad support."
echo "XFCE4 is installed. Launch manually with 'startxfce4' if desired."
echo "JWM and IceWM menus now list all installed applications."
echo "--------------------------------------------------"
