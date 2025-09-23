#!/bin/bash
# Clean TTY boot menu setup: Python PS3 mapper + AntimicroX in X + RetroArch

set -e

USER_NAME=$(whoami)
BOOTMENU_PATH="/usr/local/bin/bootmenu.sh"
ICEWM_MENU="$HOME/.icewm/menu"
AUTOSTART_DIR="$HOME/.config/autostart"
ANTIMICROX_CONFIG="$HOME/.config/antimicrox/gamepad.profile"
RETROARCH_CONFIG="$HOME/.config/retroarch"
RETROARCH_CORES_DIR="$RETROARCH_CONFIG/cores"
PS3_PYTHON="/usr/local/bin/ps3_to_keys.py"

echo "=== Remove old non-working joystick packages ==="
sudo apt remove --purge -y joy2key joystick xboxdrv || true
sudo rm -f /usr/local/bin/start-joymap.sh

echo "=== Install required packages ==="
sudo apt update
sudo apt install -y retroarch icewm xfce4 xfce4-goodies xinit xserver-xorg-core \
    xserver-xorg-input-all xserver-xorg-video-vesa dialog sudo antimicrox wget unzip \
    python3-evdev python3-uinput

# Load uinput module for keyboard emulation
sudo modprobe uinput

# Add user to input group for joystick access
sudo usermod -aG input $USER_NAME

# -------------------------------
# Step 1: Python PS3 TTY mapper
# -------------------------------
sudo tee $PS3_PYTHON > /dev/null << 'EOF'
#!/usr/bin/env python3
import evdev, uinput, glob, sys

devices = [evdev.InputDevice(fn) for fn in glob.glob("/dev/input/js*")]
if not devices:
    print("No joystick found")
    sys.exit(1)

dev = devices[0]
dev.grab()

events = (uinput.KEY_ENTER, uinput.KEY_ESC, uinput.KEY_SPACE, uinput.KEY_BACKSPACE,
          uinput.KEY_UP, uinput.KEY_DOWN, uinput.KEY_LEFT, uinput.KEY_RIGHT)
ui = uinput.Device(events)

BTN_MAP = {304: uinput.KEY_ENTER, 305: uinput.KEY_ESC, 307: uinput.KEY_BACKSPACE, 308: uinput.KEY_SPACE}
AXIS_UPDOWN = 7
AXIS_LEFTRIGHT = 6

for event in dev.read_loop():
    if event.type == evdev.ecodes.EV_KEY:
        key = BTN_MAP.get(event.code)
        if key:
            ui.emit(key, event.value)
    elif event.type == evdev.ecodes.EV_ABS:
        if event.code == AXIS_UPDOWN:
            ui.emit(uinput.KEY_UP, 1 if event.value==-1 else 0)
            ui.emit(uinput.KEY_DOWN, 1 if event.value==1 else 0)
        elif event.code == AXIS_LEFTRIGHT:
            ui.emit(uinput.KEY_LEFT, 1 if event.value==-1 else 0)
            ui.emit(uinput.KEY_RIGHT, 1 if event.value==1 else 0)
EOF

sudo chmod +x $PS3_PYTHON

# -------------------------------
# Step 2: Boot menu script
# -------------------------------
sudo tee $BOOTMENU_PATH > /dev/null << EOF
#!/bin/bash
while true; do
CHOICE=\$(dialog --clear --backtitle "Debian Boot Menu" \
--title "Boot Menu" \
--menu "Choose an option:" 15 50 6 \
1 "Launch RetroArch (fullscreen)" \
2 "Launch IceWM Desktop" \
3 "Launch XFCE4 Desktop" \
4 "Reboot" \
5 "Shutdown" 3>&1 1>&2 2>&3)

clear
case \$CHOICE in
1) retroarch -f ;;
2) echo "exec icewm-session" > ~/.xinitrc; startx ;;
3) echo "exec startxfce4" > ~/.xinitrc; startx ;;
4) sudo reboot ;;
5) sudo shutdown now ;;
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
# Step 8: RetroArch cores
# -------------------------------
mkdir -p "$RETROARCH_CORES_DIR"
cd "$RETROARCH_CONFIG"
if wget -q http://buildbot.libretro.com/nightly/linux/x86_64/latest/cores.zip -O cores.zip; then
    unzip -o cores.zip -d cores
    rm cores.zip
fi

# -------------------------------
# Step 9: Python PS3 mapper systemd service
# -------------------------------
sudo tee /etc/systemd/system/ps3keys.service > /dev/null << EOF
[Unit]
Description=PS3 Controller Keyboard Mapper
After=dev-input-joystick.device

[Service]
ExecStart=$PS3_PYTHON
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ps3keys
sudo systemctl start ps3keys

echo "=== Setup complete! ==="
echo "Reboot to test TTY boot menu with PS3 controller."
echo "AntimicroX will start in IceWM and XFCE4."
