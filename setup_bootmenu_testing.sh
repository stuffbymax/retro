#!/bin/bash
# setup_bootmenu.sh - Debian boot menu with RetroArch, IceWM, XFCE4, and AntimicroX control

set -e

USER_NAME=$(whoami)
BOOTMENU_PATH="/usr/local/bin/bootmenu.sh"
ICEWM_MENU="$HOME/.icewm/menu"
AUTOSTART_DIR="$HOME/.config/autostart"
ANTIMICROX_CONFIG="$HOME/.config/antimicrox/gamepad.profile"   # <-- adjust profile filename if needed

echo "=== Installing required packages ==="
sudo apt update
sudo apt install -y retroarch icewm xfce4 xinit xserver-xorg-core xserver-xorg-input-all xserver-xorg-video-vesa dialog joystick antimicrox sudo

echo "=== Creating boot menu script ==="
sudo tee $BOOTMENU_PATH > /dev/null << EOF
#!/bin/bash
# bootmenu.sh - Text-based boot menu on tty1 with AntimicroX management

start_antimicrox() {
    if ! pgrep -x antimicrox >/dev/null; then
        antimicrox --hidden --profile $ANTIMICROX_CONFIG &
        sleep 2
    fi
}

stop_antimicrox() {
    pkill -x antimicrox 2>/dev/null || true
}

# Start antimicrox when entering menu
start_antimicrox

while true; do
    CHOICE=\$(dialog --clear --backtitle "Debian Boot Menu" \
        --title "Boot Menu" \
        --menu "Choose an option:" 15 50 6 \
        1 "Launch RetroArch (fullscreen)" \
        2 "Launch IceWM Desktop" \
        3 "Launch XFCE4 Desktop" \
        4 "Reboot" \
        5 "Shutdown" \
        3>&1 1>&2 2>&3)

    clear
    case \$CHOICE in
        1)
            stop_antimicrox
            retroarch -f
            start_antimicrox
            ;;
        2)
            echo "exec icewm-session" > ~/.xinitrc
            startx
            ;;
        3)
            echo "exec startxfce4" > ~/.xinitrc
            startx
            ;;
        4)
            sudo reboot
            ;;
        5)
            sudo shutdown now
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
done
EOF

sudo chmod +x $BOOTMENU_PATH

echo "=== Configuring auto-login on tty1 ==="
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER_NAME --noclear %I \$TERM
EOF

sudo systemctl daemon-reexec

echo "=== Configuring .bash_profile to launch boot menu ==="
grep -qxF '[ "$(tty)" = "/dev/tty1" ] && exec /usr/local/bin/bootmenu.sh' ~/.bash_profile || \
    echo '[ "$(tty)" = "/dev/tty1" ] && exec /usr/local/bin/bootmenu.sh' >> ~/.bash_profile

echo "=== Configuring IceWM menu ==="
mkdir -p "$(dirname "$ICEWM_MENU")"
cat > "$ICEWM_MENU" << EOF
prog "RetroArch" retroarch -f
sep
prog "Reboot" sudo reboot
prog "Shutdown" sudo shutdown now
EOF

echo "=== Configuring XFCE4 and IceWM autostart for AntimicroX ==="
mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_DIR/antimicrox.desktop" << EOF
[Desktop Entry]
Type=Application
Exec=antimicrox --hidden --profile $ANTIMICROX_CONFIG
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=AntimicroX
Comment=Start AntimicroX with profile
EOF

echo "=== Setup complete! ==="
echo "Reboot your system to see the boot menu on tty1."
echo "AntimicroX starts automatically in the menu and desktop sessions."
echo "When launching RetroArch, AntimicroX is stopped; it restarts after RetroArch exits."
