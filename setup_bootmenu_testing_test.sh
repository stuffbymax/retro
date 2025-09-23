#!/bin/bash
set -e

USER_NAME=$(whoami)
BOOTMENU="/usr/local/bin/bootmenu.sh"
PS3_PYTHON="/usr/local/bin/ps3_to_keys.py"
ICEWM_MENU="$HOME/.icewm/menu"
AUTOSTART_DIR="$HOME/.config/autostart"
ANTIMICROX_PROFILE="$HOME/.config/antimicrox/bootmenu_gamepad_profile.amgp"
RETROARCH_CONFIG="$HOME/.config/retroarch"
RETROARCH_CORES_DIR="$RETROARCH_CONFIG/cores"

# -------------------------------
# Step 0: Prepare environment
# -------------------------------
sudo apt update
sudo apt install -y retroarch icewm xfce4 xfce4-goodies xinit \
xserver-xorg-core xserver-xorg-input-all xserver-xorg-video-vesa \
dialog sudo antimicrox unzip python3-evdev python3-uinput wget

sudo modprobe uinput
sudo usermod -aG input $USER_NAME

mkdir -p "$RETROARCH_CORES_DIR"
mkdir -p "$AUTOSTART_DIR"

# -------------------------------
# Step 1: Python PS3 TTY mapper
# -------------------------------
sudo tee $PS3_PYTHON > /dev/null << 'EOF'
#!/usr/bin/env python3
import evdev, uinput, sys

def find_ps3_controller():
    devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
    for device in devices:
        if "PLAYSTATION" in device.name.upper() or "PS3" in device.name.upper():
            return device
    print("PS3 controller not found.")
    sys.exit(1)

device = find_ps3_controller()
print(f"Using device: {device.path} ({device.name})")

events = (uinput.KEY_ENTER, uinput.KEY_ESC, uinput.KEY_SPACE, uinput.KEY_BACKSPACE,
          uinput.KEY_UP, uinput.KEY_DOWN, uinput.KEY_LEFT, uinput.KEY_RIGHT)
ui = uinput.Device(events)

BTN_MAP = {
    304: uinput.KEY_ENTER,       # X
    305: uinput.KEY_ESC,         # Circle
    307: uinput.KEY_BACKSPACE,   # Square
    308: uinput.KEY_SPACE,       # Triangle
    544: uinput.KEY_UP,          # D-pad Up
    545: uinput.KEY_DOWN,        # D-pad Down
    546: uinput.KEY_LEFT,        # D-pad Left
    547: uinput.KEY_RIGHT        # D-pad Right
}

device.grab()
for event in device.read_loop():
    if event.type == evdev.ecodes.EV_KEY:
        key = BTN_MAP.get(event.code)
        if key is not None:
            ui.emit(key, event.value)
EOF
sudo chmod +x $PS3_PYTHON

# -------------------------------
# Step 2: Boot menu script
# -------------------------------
sudo tee $BOOTMENU > /dev/null << EOF
#!/bin/bash
# Start Python PS3 mapper in background
$PS3_PYTHON &
PS3_PID=\$!

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
1)
    kill \$PS3_PID 2>/dev/null || true
    retroarch -f
    $PS3_PYTHON &
    PS3_PID=\$!
    ;;
2)
    kill \$PS3_PID 2>/dev/null || true
    echo "exec icewm-session" > ~/.xinitrc
    # Start AntimicroX in IceWM
    antimicrox --hidden --profile $ANTIMICROX_PROFILE &
    startx
    ;;
3)
    kill \$PS3_PID 2>/dev/null || true
    echo "exec startxfce4" > ~/.xinitrc
    # Start AntimicroX in XFCE
    antimicrox --hidden --profile $ANTIMICROX_PROFILE &
    startx
    ;;
4)
    kill \$PS3_PID 2>/dev/null || true
    sudo reboot
    ;;
5)
    kill \$PS3_PID 2>/dev/null || true
    sudo shutdown now
    ;;
esac
done
EOF
sudo chmod +x $BOOTMENU

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

# Auto-launch boot menu on tty1
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
# Step 5: AntimicroX autostart for XFCE
# -------------------------------
cat > "$AUTOSTART_DIR/antimicrox.desktop" << EOF
[Desktop Entry]
Type=Application
Exec=antimicrox --hidden --profile $ANTIMICROX_PROFILE
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=AntimicroX
Comment=Start AntimicroX with profile
EOF

# -------------------------------
# Step 6: Download RetroArch cores
# -------------------------------
cd "$RETROARCH_CORES_DIR"
wget -r -np -nH --cut-dirs=3 -A "*.zip" https://buildbot.libretro.com/nightly/linux/x86_64/latest/
find . -name "*.zip" -exec unzip -o {} \;
find . -name "*.zip" -delete

# -------------------------------
# Step 7: PS3 mapper systemd service (optional)
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

echo "=== Setup complete! Reboot to test ==="
