#!/bin/bash
# retro-debian-dual-gp.sh
# Debian Dual-Mode OS: RetroArch-first, DWM desktop default, optional XFCE4
# System-wide gamepad support with antimicrox autostart (except RetroArch)

set -e

RETRO_USER="retro"

echo "[*] Updating system..."
apt update && apt upgrade -y

echo "[*] Installing essentials + lightweight desktop + RetroArch + gamepad tools..."
apt install -y xorg xinit mesa-utils dwm suckless-tools stterm dmenu firmware-linux-free firmware-linux-nonfree git curl wget unzip retroarch libretro-* retroarch-assets joystick gamecon-driver-utils antimicrox libsdl2-2.0-0

# Optional XFCE4 installation
read -p "Do you want to install XFCE4 as optional desktop? [y/N]: " INSTALL_XFCE
if [[ "$INSTALL_XFCE" =~ ^[Yy]$ ]]; then
    echo "[*] Installing XFCE4..."
    apt install -y xfce4 lightdm
fi

echo "[*] Adding retro user..."
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

echo "[*] Configuring RetroArch autostart + dual-mode..."
su - "$RETRO_USER" -c "cat > ~/.bash_profile <<'EOP'
if [[ -z \$DISPLAY ]] && [[ \$(tty) == /dev/tty1 ]]; then
    exec startx
fi
EOP"

# Build dual-mode menu dynamically
su - "$RETRO_USER" -c "cat > ~/.xinitrc <<'EOP'
#!/bin/bash
echo \"Choose Mode:\"
echo \"1) RetroArch (Console)\"
echo \"2) DWM Desktop (OS)\"
EOP"

if [[ "$INSTALL_XFCE" =~ ^[Yy]$ ]]; then
    su - "$RETRO_USER" -c "cat >> ~/.xinitrc <<'EOP'
echo \"3) XFCE4 Desktop (Optional OS)\"
EOP"
fi

su - "$RETRO_USER" -c "cat >> ~/.xinitrc <<'EOP'
read -p \"Select [1-$( [[ \"$INSTALL_XFCE\" =~ ^[Yy]$ ]] && echo 3 || echo 2)]: \" choice

case \$choice in
    1) exec retroarch ;;
    2) 
        # Autostart antimicrox in DWM
        antimicrox --hidden &
        exec dwm ;;
EOP"

if [[ "$INSTALL_XFCE" =~ ^[Yy]$ ]]; then
    su - "$RETRO_USER" -c "cat >> ~/.xinitrc <<'EOP'
    3) 
        # Autostart antimicrox in XFCE4
        antimicrox --hidden &
        exec startxfce4 ;;
EOP"
fi

su - "$RETRO_USER" -c "cat >> ~/.xinitrc <<'EOP'
    *) exec retroarch ;;
esac
EOP
chmod +x ~/.xinitrc"

# Add retro user to input + plugdev for controller access
usermod -aG input $RETRO_USER
usermod -aG plugdev $RETRO_USER

# Install SDL2 controller database for better mappings
su - "$RETRO_USER" -c "mkdir -p ~/.config && wget -q \
https://raw.githubusercontent.com/gabomdq/SDL_GameControllerDB/master/gamecontrollerdb.txt \
-O ~/.config/gamecontrollerdb.txt"
echo "SDL_GAMECONTROLLERCONFIG=/home/$RETRO_USER/.config/gamecontrollerdb.txt" >> /etc/environment

echo "[*] Setup complete!"
echo "Reboot now. System boots into RetroArch by default."
echo "From TTY, run 'startx' to choose between RetroArch, DWM, or XFCE4 (if installed)."
echo "Controllers are enabled system-wide, with antimicrox autostart in desktop modes."
