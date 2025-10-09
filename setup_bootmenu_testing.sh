#!/bin/bash
set -e

USER_NAME=$(whoami)
BOOTMENU="/usr/local/bin/bootmenu.sh"
PS3_PYTHON="/usr/local/bin/ps3_to_keys.py"
ICEWM_MENU="$HOME/.icewm/menu"
AUTOSTART_DIR="$HOME/.config/autostart"
ANTIMICROX_PROFILE="$HOME/.config/antimicrox/bootmenu_gamepad_profile.amgp"
RETROARCH_CONFIG="$HOME/.config/retroarch"
RETROARCH_CORES_DIR="$HOME/.config/retroarch/cores"


#echo "=== Install required packages ==="
sudo apt update
sudo apt install -y retroarch icewm xfce4 xfce4-goodies xinit xserver-xorg-core xserver-xorg-input-all xserver-xorg-video-vesa dialog sudo antimicrox unzip python3-evdev python3-uinput wget curl neovim tmux 

# Load uinput and add user to input group
#sudo modprobe uinput
#sudo usermod -aG input $USER_NAME


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
    304: uinput.KEY_ENTER,  # X
    305: uinput.KEY_ESC,    # Circle
    307: uinput.KEY_BACKSPACE, # Square
    308: uinput.KEY_SPACE,      # Triangle
    544: uinput.KEY_UP,         # D-pad Up
    545: uinput.KEY_DOWN,       # D-pad Down
    546: uinput.KEY_LEFT,       # D-pad Left
    547: uinput.KEY_RIGHT       # D-pad Right
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
--menu "Choose an option:" 15 50 7 \
1 "Launch RetroArch (fullscreen)" \
2 "Launch IceWM Desktop" \
3 "Launch XFCE4 Desktop" \
4 "Launch TWM Desktop" \
5 "Reboot" \
6 "Shutdown" 3>&1 1>&2 2>&3)


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
    onboard &
    startx
    $PS3_PYTHON &
    PS3_PID=\$!
    ;;
3)
    kill \$PS3_PID 2>/dev/null || true
    echo "exec startxfce4" > ~/.xinitrc
    # Start AntimicroX in XFCE
    antimicrox --hidden --profile $ANTIMICROX_PROFILE &
    onboard &
    startx
    $PS3_PYTHON &
    PS3_PID=\$!
    ;;
4)
    kill $PS3_PID 2>/dev/null || true
    echo "exec twm" > ~/.xinitrc
    antimicrox --hidden --profile $ANTIMICROX_PROFILE &
    onboard &
    startx
    $PS3_PYTHON &
    PS3_PID=$!
    ;;
5)
    kill $PS3_PID 2>/dev/null || true
    sudo reboot
    ;;
6)
    kill $PS3_PID 2>/dev/null || true
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

# Launch boot menu automatically on tty1
grep -qxF '[ "$(tty)" = "/dev/tty1" ] && exec /usr/local/bin/bootmenu.sh' ~/.bash_profile || \
echo '[ "$(tty)" = "/dev/tty1" ] && exec /usr/local/bin/bootmenu.sh' >> ~/.bash_profile

# -------------------------------
# Step 4: IceWM menu
# -------------------------------
mkdir -p "$(dirname "$ICEWM_MENU")"
cat > "$ICEWM_MENU" << EOF

menuprog "apps" folder icewm-menu-fdo
prog Terminal x-terminal-emulator x-terminal-emulator
prog FileManager thunar thunar

sep

prog Restart IceWM restart icewm --restart
prog Logout logout logout
EOF

# -------------------------------
# Step 5: AntimicroX autostart for XFCE4
# -------------------------------
mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_DIR/antimicrox.desktop" << EOF
[Desktop Entry]
Type=Application
Exec=antimicrox --hidden --profile /home/zdislav/.config/antimicrox/bootmenu_gamepad_profile.amgp
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=AntimicroX
Comment=Start AntimicroX with profile

EOF

# -------------------------------
# Step 6: AntimicroX + Onboard autostart for IceWM
# -------------------------------
mkdir -p ~/.icewm
cat > ~/.icewm/startup << EOF
#!/bin/bash
# Start AntimicroX with profile
antimicrox --hidden --profile $ANTIMICROX_PROFILE &

# Start Onboard on-screen keyboard
onboard &
EOF
chmod +x ~/.icewm/startup


# -------------------------------
# Step6.1: Onboard autostart for xfce4
# -------------------------------
# Onboard autostart
cat > "$AUTOSTART_DIR/onboard.desktop" << EOF
[Desktop Entry]
Type=Application
Exec=onboard
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Onboard
Comment=Start Onboard on-screen keyboard
EOF

# -------------------------------
# Step 6.2: AntimicroX + Onboard autostart for TWM 
# note doesnt work yet with controler 
# -------------------------------
mkdir -p ~/.twm
cat > ~/.twm/startup << EOF
#!/bin/bash
# Start AntimicroX with profile
antimicrox --hidden --profile $ANTIMICROX_PROFILE &

# Start Onboard on-screen keyboard
onboard &
EOF
chmod +x ~/.twm/startup

###
# TWM configuration
###

# Create TWM directories
mkdir -p ~/.twm
mkdir -p ~/.twm/walls
mkdir -p ~/.twm/icons

# -------------------------------
# ~/.twm/colors
# -------------------------------
cat > ~/.twm/colors << 'EOF'
Color
{
    BorderColor         "#303639"
    DefaultBackground   "White"
    DefaultForeground   "Black"

    TitleBackground     "Firebrick"
    TitleForeground     "White"

    MenuTitleBackground "Firebrick"
    MenuTitleForeground "White"

    MenuBackground      "#FFFFFF"
    MenuForeground      "#303639"

    MenuShadowColor     "#303639"
    MenuBorderColor     "#303639"
}
EOF

# -------------------------------
# ~/.twm/twmrc
# -------------------------------
cat > ~/.twm/twmrc << 'EOF'
# Window border and menu settings
BorderWidth 1
FramePadding 1
TitleButtonBorderWidth 0
TitlePadding 2
ButtonIndent 0
MenuBorderWidth 1
NoMenuShadows

# Title bar buttons
IconDirectory "$HOME/.twm/icons"
LeftTitleButton "resize.xbm"=f.resize
RightTitleButton "minimize.xbm"=f.iconify
RightTitleButton "maximize.xbm"=f.fullzoom
RightTitleButton "close.xbm"=f.delete

# Mouse settings and window behaviors
Button1 = : root : f.menu "RootMenu"
Button2 = : root : f.menu "System"
Button3 = : root : f.menu "TwmWindows"

Movedelta 1
Button1 = :title: f.function "raise-lower-move"
Function "raise-lower-move" { f.move f.raiselower }

Button2 = : title|frame : f.menu "WindowMenu"
Button3 = : title|frame : f.resize
Button1 = m : window : f.move
Button3 = s : window : f.resize

Function "winup" { f.circleup }
"Tab" = m : root|window|frame|title : f.function "winup"

Button1 = m : title|frame : f.zoom
Button3 = m : title|frame : f.horizoom

DefaultFunction f.nop
EOF


# -------------------------------
# Step 7: Download RetroArch cores (all .zip files)
# -------------------------------
cd ".config/retroarch/cores"

# Fetch list of .zip files
wget -r -np -nH --cut-dirs=3 -A "*.zip" https://buildbot.libretro.com/nightly/linux/x86_64/latest/
find . -name "*.zip" -exec unzip -o {} \;
find . -name "*.zip" -delete


echo "All RetroArch cores downloaded and extracted."

# -------------------------------
# Step 8: Python PS3 mapper service
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
