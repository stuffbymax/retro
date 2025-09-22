#!/bin/bash
# Arch Linux RetroArch Console Setup (Intel GPU + Openbox Fallback)
# This script will WIPE old configs (~/.xinitrc, ~/.bash_profile, openbox autostart, getty overrides)
# and create a clean setup

set -e

USER_HOME="/home/$USER"

echo "=== Updating system and installing required packages ==="
sudo pacman -Syu --noconfirm \
    xorg-server xorg-xinit mesa mesa-utils xf86-video-intel \
    openbox tint2 retroarch onboard xboxdrv antimicrox \
    networkmanager network-manager-applet \
    bluez bluez-utils blueman \
    ntfs-3g

echo "=== Enabling system services (NetworkManager, Bluetooth) ==="
sudo systemctl enable NetworkManager bluetooth
sudo systemctl start NetworkManager bluetooth

echo "=== Cleaning up old configs ==="
rm -f "$USER_HOME/.xinitrc"
rm -f "$USER_HOME/.bash_profile"
rm -f "$USER_HOME/.config/openbox/autostart"
sudo rm -rf /etc/systemd/system/getty@tty1.service.d

echo "=== Setting up systemd autologin on TTY1 ==="
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo bash -c "cat > /etc/systemd/system/getty@tty1.service.d/override.conf" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF
sudo systemctl daemon-reexec

echo "=== Creating new ~/.xinitrc (Openbox) ==="
cat > "$USER_HOME/.xinitrc" <<'EOF'
exec openbox-session
EOF

echo "=== Creating new ~/.bash_profile (auto startx) ==="
cat > "$USER_HOME/.bash_profile" <<'EOF'
if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
    exec startx
fi
EOF

echo "=== Creating Openbox autostart (RetroArch + fallback) ==="
mkdir -p "$USER_HOME/.config/openbox"
cat > "$USER_HOME/.config/openbox/autostart" <<'EOF'
# Start RetroArch fullscreen at login
retroarch --fullscreen
# If RetroArch exits, start fallback environment
tint2 &
onboard &
antimicrox --profile ~/.config/antimicrox/retro_fallback.profile &
EOF

echo "=== Creating system-wide RetroArch shortcut ==="
sudo bash -c "cat > /usr/share/applications/retroarch.desktop" <<EOF
[Desktop Entry]
Name=RetroArch
Comment=Launch RetroArch
Exec=$USER_HOME/start_retroarch.sh
Icon=retroarch
Terminal=false
Type=Application
Categories=Game;Emulator;
EOF
sudo chown root:root /usr/share/applications/retroarch.desktop
sudo chmod 755 /usr/share/applications/retroarch.desktop

echo "=== Creating RetroArch manual launcher script ==="
cat > "$USER_HOME/start_retroarch.sh" <<'EOF'
#!/bin/bash
sudo xboxdrv --daemon
retroarch --fullscreen
EOF
chmod +x "$USER_HOME/start_retroarch.sh"

echo "=== Setup complete! Reboot to test ==="
