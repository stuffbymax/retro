#!/bin/bash
# Clean previous failed setup and install working boot menu with PS3 controller in TTY
set -e

USER_NAME=$(whoami)
BOOTMENU_PATH="/usr/local/bin/bootmenu.sh"
ICEWM_MENU="$HOME/.icewm/menu"
AUTOSTART_DIR="$HOME/.config/autostart"
ANTIMICROX_CONFIG="$HOME/.config/antimicrox/gamepad.profile"
RETROARCH_CONFIG="$HOME/.config/retroarch"
RETROARCH_CORES_DIR="$RETROARCH_CONFIG/cores"

echo "=== Removing non-working joy2key ==="
# Remove packages
sudo apt remove --purge -y joy2key joystick

# Remove leftover scripts if they exist
sudo rm -f /usr/local/bin/start-joymap.sh

# Optional: remove any custom joystick config files
rm -f ~/.start-joymap.sh


echo "=== Installing required packages ==="
sudo apt update
sudo apt install -y retroarch icewm xfce4 xfce4-goodies xinit xserver-xorg-core \
    xserver-xorg-input-all xserver-xorg-video-vesa dialog sudo antimicrox \
    wget unzip xboxdrv

# -------------------------------
# Step 1: Create boot menu script
# -------------------------------
sudo tee $BOOTMENU_PATH > /dev/null << EOF
#!/bin/bash
# bootmenu.sh - Text-based boot menu on tty1 with xboxdrv support

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
            retroarch -f
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
    esac
done
EOF
sudo chmod +x $BOOTMENU_PATH

# -------------------------------
# Step 2: Auto-login on tty1
# -------------------------------
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER_NAME --noclear %I \$TERM
EOF
sudo systemctl daemon-reexec

# -------------------------------
# Step 3: Launch boot menu automatically
# -------------------------------
grep -qxF '[ "$(tty)" = "/dev/tty1" ] && exec /usr/local/bin/bootmenu.sh' ~/.bash_profile || \
    echo '[ "$(tty)" = "/dev/tty1" ] && exec /usr/local/bin/bootmenu.sh' >> ~/.bash_profile

# -------------------------------
# Step 4: IceWM menu
# -------------------------------
mkdir -p "$(dirname "$ICEWM_MENU")"
cat > "$ICEWM_MENU" << EOF
prog "RetroArch" retroarch -f
sep
prog "Reboot" sudo reboot
prog "Shutdown" sudo shutdown now
EOF

# -------------------------------
# Step 5: AntimicroX autostart for XFCE4
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
# Step 6: AntimicroX autostart for IceWM
# -------------------------------
mkdir -p ~/.icewm
cat > ~/.icewm/startup << EOF
#!/bin/bash
antimicrox --hidden --profile $ANTIMICROX_CONFIG &
EOF
chmod +x ~/.icewm/startup

# -------------------------------
# Step 7: Download and setup RetroArch cores
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

# -------------------------------
# Step 8: Setup xboxdrv for TTY joystick mapping
# -------------------------------
echo "=== Creating xboxdrv systemd service ==="
sudo tee /etc/systemd/system/xboxdrv.service > /dev/null << EOF
[Unit]
Description=PS3 controller mapping for TTY
After=dev-input-joystick.device

[Service]
ExecStart=/usr/bin/xboxdrv --evdev /dev/input/js0 --evdev-keymap \
    BTN_A=KEY_ENTER,BTN_B=KEY_ESC,BTN_X=KEY_SPACE,BTN_Y=KEY_BACKSPACE \
    --silent
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable xboxdrv
sudo systemctl start xboxdrv

echo "=== Setup complete! ==="
echo "Reboot your system to see the boot menu on tty1."
echo "PS3 controller should now work in the TUI menu via xboxdrv."
echo "AntimicroX starts automatically in IceWM and XFCE4."
