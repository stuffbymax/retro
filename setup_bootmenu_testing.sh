#!/bin/bash
# setup_bootmenu.sh - Debian boot menu with RetroArch, IceWM, XFCE4,
# AntimicroX in X, joystick mapping in console, and RetroArch cores.

set -e

USER_NAME=$(whoami)
BOOTMENU_PATH="/usr/local/bin/bootmenu.sh"
JOYMAP_SCRIPT="/usr/local/bin/start-joymap.sh"
ICEWM_MENU="$HOME/.icewm/menu"
AUTOSTART_DIR="$HOME/.config/autostart"
ANTIMICROX_CONFIG="$HOME/.config/antimicrox/gamepad.profile"
RETROARCH_CORES_DIR="$HOME/.config/retroarch/cores"

echo "=== Installing required packages ==="
sudo apt update
sudo apt install -y retroarch icewm xfce4 xfce4-goodies xinit xserver-xorg-core \
    xserver-xorg-input-all xserver-xorg-video-vesa dialog sudo antimicrox \
    wget unzip joystick

echo "=== Creating joystick mapping script ==="
sudo tee $JOYMAP_SCRIPT > /dev/null << 'EOF'
#!/bin/bash
# start-joymap.sh - PS3 controller mapping to keyboard keys

# Kill existing joy2key if running
pkill -x joy2key 2>/dev/null || true

# Map PS3 joystick: D-pad = arrows, X=Enter, Circle=Escape, Select=Backspace, Start=Enter
joy2key /dev/input/js0 \
    up down left right \
    enter escape backspace enter &
EOF
sudo chmod +x $JOYMAP_SCRIPT

echo "=== Creating boot menu script ==="
sudo tee $BOOTMENU_PATH > /dev/null << EOF
#!/bin/bash
# bootmenu.sh - Text-based boot menu on tty1 with joystick support

JOYMAP_SCRIPT="$JOYMAP_SCRIPT"

start_joymap() {
    \$JOYMAP_SCRIPT
}

stop_joymap() {
    pkill -x joy2key 2>/dev/null || true
}

# Start joystick mapping for menu navigation
start_joymap

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
            stop_joymap
            retroarch -f
            start_joymap
            ;;
        2)
            echo "exec icewm-session" > ~/.xinitrc
            stop_joymap
            startx
            start_joymap
            ;;
        3)
            echo "exec startxfce4" > ~/.xinitrc
            stop_joymap
            startx
            start_joymap
            ;;
        4)
            sudo reboot
            ;;
        5)
            sudo shutdown now
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

mkdir -p ~/.icewm
cat > ~/.icewm/startup << EOF
#!/bin/bash
antimicrox --hidden --profile $ANTIMICROX_CONFIG &
EOF
chmod +x ~/.icewm/startup

echo "=== Setting up RetroArch cores ==="
mkdir -p "$RETROARCH_CORES_DIR"
cd "$RETROARCH_CORES_DIR"
CORE_URL="http://buildbot.libretro.com/nightly/linux/x86_64/latest/"
CORE_ZIP=\$(wget -qO- "\$CORE_URL" | grep -o 'href="[^"]*zip"' | head -n1 | cut -d'"' -f2)
if [ -n "\$CORE_ZIP" ]; then
    echo "Downloading cores from: \$CORE_URL\$CORE_ZIP"
    wget -q "\$CORE_URL\$CORE_ZIP" -O cores.zip
    unzip -o cores.zip
    rm cores.zip
else
    echo "Warning: Could not fetch RetroArch cores package."
fi

echo "=== Setup complete! ==="
echo "Reboot your system to see the boot menu on tty1."
echo "Use PS3 joystick to navigate the menu (D-pad + X=Enter, Circle=Escape)."
echo "RetroArch runs without joy2key interference; mapping resumes after exit."
