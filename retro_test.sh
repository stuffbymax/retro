#!/bin/bash
# retro-debian-console.sh
# Debian Dual-Mode OS: RetroArch-first, DWM desktop default, optional XFCE4
# Full system-wide gamepad support, antimicrox autostart in desktop only

set -e

RETRO_USER="zdislav"

echo "[*] Updating system..."
apt update && apt upgrade -y

echo "[*] Installing essentials + lightweight desktop + RetroArch + gamepad tools..."
apt install -y xorg xinit mesa-utils dwm suckless-tools stterm dmenu firmware-linux-free firmware-linux-nonfree git curl wget unzip retroarch libretro-* retroarch-assets joystick antimicrox libsdl2-2.0-0

# Optional XFCE4 installation
read -p "Do you want to install XFCE4 as optional desktop? [y/N]: " INSTALL_XFCE
if [[ "$INSTALL_XFCE" =~ ^[Yy]$ ]]; then
    echo "[*] Installing XFCE4..."
    apt install -y xfce4 lightdm
fi

echo "[*] Adding $RETRO_USER user..."
if ! id "$RETRO_USER" &>/dev/null; then
    adduser --disabled-password --gecos "" "$RETRO_USER"
fi

echo "[*] Enabling autologin for $RETRO_USER..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $RETRO_USER --noclear %I \$TERM
EOF

echo "[*] Configuring RetroArch first boot + desktop fallback..."
cat > /home/$RETRO_USER/.xinitrc <<'EOP'
#!/bin/bash
# Launch RetroArch first
retroarch

# When RetroArch exits, launch desktop
if command -v startxfce4 >/dev/null 2>&1; then
    # XFCE installed
    antimicrox --hidden &
    exec startxfce4
else
    # Default lightweight desktop DWM
    antimicrox --hidden &
    exec dwm
fi
EOP

chown $RETRO_USER:$RETRO_USER /home/$RETRO_USER/.xinitrc
chmod +x /home/$RETRO_USER/.xinitrc

echo "[*] Configure autostart of X for $RETRO_USER..."
cat > /home/$RETRO_USER/.bash_profile <<'EOP'
if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
    exec startx
fi
EOP

chown $RETRO_USER:$RETRO_USER /home/$RETRO_USER/.bash_profile
chmod +x /home/$RETRO_USER/.bash_profile

echo "[*] Adding $RETRO_USER to input and plugdev for controller access..."
usermod -aG input,plugdev $RETRO_USER

echo "[*] Installing SDL2 controller database for better mappings..."
mkdir -p /home/$RETRO_USER/.config
wget -q https://raw.githubusercontent.com/gabomdq/SDL_GameControllerDB/master/gamecontrollerdb.txt \
    -O /home/$RETRO_USER/.config/gamecontrollerdb.txt
chown -R $RETRO_USER:$RETRO_USER /home/$RETRO_USER/.config
echo "SDL_GAMECONTROLLERCONFIG=/home/$RETRO_USER/.config/gamecontrollerdb.txt" >> /etc/environment

echo "[*] Setup complete!"
echo "Reboot now. System boots into RetroArch automatically."
echo "Exit RetroArch to switch to desktop mode (DWM or XFCE if installed)."
echo "Controllers are enabled system-wide, with antimicrox autostart in desktop modes."
