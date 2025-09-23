#!/bin/bash
# setup_bootmenu.sh - Debian boot menu with RetroArch, IceWM, XFCE4,
# AntimicroX in X, joystick mapping in TUI, and RetroArch cores.

set -e

USER_NAME=$(whoami)
BOOTMENU_PATH="/usr/local/bin/bootmenu.sh"
JOYMAP_SCRIPT="/usr/local/bin/start-joymap.sh"
ICEWM_MENU="$HOME/.icewm/menu"
AUTOSTART_DIR="$HOME/.config/autostart"
ANTIMICROX_CONFIG="$HOME/.config/antimicrox/gamepad.profile"
RETROARCH_CONFIG="$HOME/.config/retroarch"
RETROARCH_CORES_DIR="$RETROARCH_CONFIG/cores"

echo "=== Installing required packages ==="
sudo apt update
sudo apt install -y retroarch icewm xfce4 xfce4-goodies xinit xserver-xorg-core \
    xserver-xorg-input-all xserver-xorg-video-vesa dialog sudo antimicrox \
    wget unzip joystick

# Add user to input group for joystick access
sudo usermod -aG input $USER_NAME

# -------------------------------
# Step 1: Create joystick mapping script (auto-detect device)
# -------------------------------
sudo tee $JOYMAP_SCRIPT > /dev/null << 'EOF'
#!/bin/bash
# start-joymap.sh - Auto-detect first joystick and map buttons

# Kill previous joy2key
pkill -x joy2key 2>/dev/null || true

# Detect first joystick device
JS_DEV=$(ls /dev/input/js* 2>/dev/null | head -n1)
if [ -z "$JS_DEV" ]; then
    echo "No joystick found"
    exit 1
fi

# Map PS3 joystick: D-pad = arrows, X=Enter, Circle=Escape, Select=Backspace, Start=Enter
joy2key "$JS_DEV" \
    up down left right \
    enter escape backspace enter &
EOF
sudo chmod +x $JOYMAP_SCRIPT

# -------------------------------
# Step 2: Create boot menu script
# -------------------------------
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

# -------------------------------
# Step 3: Auto-login on tty1
# -------------------------------
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER_NAME --noclear %I \$TERM
EOF
sudo systemctl daemon-reexec

# -------------------------------
# Step 4: Launch boot menu automatically
# -------------------------------
grep -qxF '[ "$(tty)" = "/dev/tty1" ] && exec /usr/local/bin/bootmenu.sh' ~/.bash_profile || \
    echo '[ "$(tty)" = "/dev/tty1" ] && exec /usr/local/bin/bootmenu.sh' >> ~/.bash_profile

# -------------------------------
# Step 5: IceWM menu
# -------------------------------
mkdir -p "$(dirname "$ICEWM_MENU")"
cat > "$ICEWM_MENU" << EOF
prog "RetroArch" retroarch -f
sep
prog "Reboot" sudo reboot
prog "Shutdown" sudo shutdown now
EOF

# -------------------------------
# Step 6: AntimicroX autostart for XFCE4
# -------------------------------
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

# -------------------------------
# Step 7: AntimicroX autostart for IceWM
# -------------------------------
mkdir -p ~/.icewm
cat > ~/.icewm/startup << EOF
#!/bin/bash
antimicrox --hidden --profile $ANTIMICROX_CONFIG &
EOF
chmod +x ~/.icewm/startup

# -------------------------------
# Step 8: Download and setup RetroArch cores
# -------------------------------
mkdir -p "$RETROARCH_CORES_DIR"
cd "$RETROARCH_CONFIG"

echo "Downloading RetroArch cores..."
if wget -q http://buildbot.libretro.com/nightly/linux/x86_64/latest/cores.zip -O cores.zip; then
    unzip -o cores.zip -d cores
    rm cores.zip
    echo "RetroArch cores installed in $RETROARCH_CORES_DIR"
else
    echo "Warning: Could not download RetroArch cores"
fi

echo "=== Setup complete! ==="
echo "Reboot your system to see the boot menu on tty1."
echo "Use PS3 joystick to navigate the menu (D-pad + X=Enter, Circle=Escape)."
echo "RetroArch runs without joy2key interference; mapping resumes after exit."
echo "AntimicroX starts automatically in IceWM and XFCE4."
echo "Make sure your user is in the 'input' group for joystick access."
