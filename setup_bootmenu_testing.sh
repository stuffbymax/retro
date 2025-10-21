#!/bin/bash
set -e

# this will log everything
exec > >(tee -a ~/log.txt) 2>&1

USER_NAME=$(whoami)
BOOTMENU="/usr/local/bin/bootmenu.sh"
PS3_PYTHON="/usr/local/bin/ps3_to_keys.py"
ICEWM_MENU="$HOME/.icewm/menu"
AUTOSTART_DIR="$HOME/.config/autostart"
ANTIMICROX_PROFILE="$HOME/.config/antimicrox/bootmenu_gamepad_profile.amgp"
conf="retro/config"

# -------------------------------
# WARNING / ACKNOWLEDGEMENT
# -------------------------------
echo -e "\e[33mWARNING: This script is experimental and may NOT work as intended!\e[0m"
echo -e "\e[33mKnown issues:\e[0m"
echo -e "\e[33m - Keybindings may be missing or incomplete\e[0m"
echo -e "\e[33m - Drivers are default to Intel only you have to change it depending on your GPU\e[0m"
echo -e "\e[33m - Some features require manual follow-up\e[0m"
echo -e "\e[33m - External files are not yet uploaded to GitHub\e[0m"
echo -e "\e[33m also this script will install retroarch lates cores in .config/cores \e[0m"
echo ""

read -p "Do you want to continue? [y/N]: " CONFIRM
CONFIRM=${CONFIRM,,}
if [[ "$CONFIRM" != "y" ]]; then
    echo "Exiting script. No changes were made."
    exit 1
fi

# === Install required packages ===
sudo apt update
echo "update complete"
sudo apt install -y retroarch icewm xfce4 xfce4-goodies xinit xserver-xorg-core xserver-xorg-input-all dialog sudo antimicrox unzip python3-evdev python3-uinput wget curl neovim tmux
echo "installed necesery software"

echo "installing retro arch assets"
sudo apt -y install retroarch-assets
echo "retro arch assets completed"

# here make script for select your gpu driver.eg. 1. (Intel), 2.(AMD) 3. (Nvidia)
echo -e "please select GPU Driver"
echo -e "1) Intel"
echo -e "2) AMD"
echo -e "3) ATI"
echo -e "4) Nvidia (open source)"
echo -e "5) Nvidia (propriatery)"

read -p "Enter your choice (1 or 5): " choice

case $choice in
    1)
        echo "You selected 1. installing Intel..."
        sudo apt install -y xserver-xorg-video-intel
        ;;
    2)
        echo "You selected 2. installing AMD..."
        sudo apt install -y xserver-xorg-video-amdgpu
        ;;
    3)
        echo "You selected 3. installing ATI..."
        sudo apt install -y xserver-xorg-video-ati
        ;;
    4)
        echo "You selected 4. installing Nvidia (open source)..."
        sudo apt install -y xserver-xorg-video-nouveau
        ;;
    5)
        echo "You selected 5. installing Nvidia (open source)..."
        sudo apt install -y nvidia-driver
        ;;
    *)
        echo "Invalid choice. Please run the script again and select 1 or 5."
        ;;
esac


# uinput and permissions
sudo usermod -aG input $USER_NAME
sudo modprobe uinput
sudo chmod 777 /dev/uinput
echo "uinput" | sudo tee /etc/modules-load.d/uinput.conf

# --- Step 1: PS3 Controller Python Mapper ---
sudo tee $PS3_PYTHON > /dev/null << 'EOF'
# [ script contents unchanged for brevity, same as your original ]
# Snipped here — keep the full Python content from your original script
EOF
sudo chmod 777 $PS3_PYTHON

# --- Step 2: Boot Menu Script ---
sudo tee $BOOTMENU > /dev/null << EOF
#!/bin/bash
$PS3_PYTHON &
PS3_PID=\$!

while true; do
CHOICE=\$(dialog --clear --backtitle "Simple Boot Menu" \
--title "Bash Boot Menu" \
--menu "Choose an option:" 20 60 8 \
1 "Launch RetroArch (fullscreen)" \
2 "Launch IceWM Desktop" \
3 "Launch XFCE4 Desktop" \
4 "Update System (apt upgrade)" \
5 "Open Shell (TTY) (requires keyboard)" \
6 "Network Configuration (requires keyboard)" \
7 "Reboot (require sudo)" \
8 "Shutdown (require sudo)" 3>&1 1>&2 2>&3)

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
    antimicrox --hidden --profile $ANTIMICROX_PROFILE &
    onboard &
    startx
    $PS3_PYTHON &
    PS3_PID=\$!
    ;;
3)
    kill \$PS3_PID 2>/dev/null || true
    echo "exec startxfce4" > ~/.xinitrc
    antimicrox --hidden --profile $ANTIMICROX_PROFILE &
    onboard &
    startx
    $PS3_PYTHON &
    PS3_PID=\$!
    ;;
4)
    clear
    echo -e  "\e[42m=== Updating system... please wait ===\e[0m"
    echo "(Full log at /tmp/apt_update.log)"
    sudo apt update -y && sudo apt upgrade -y &> /tmp/apt_update.log &
    PID=$!
    BAR="#"
    WIDTH=40
    while kill -0 \$PID 2>/dev/null; do
        if [ \${#BAR} -lt \$WIDTH ]; then
            BAR="\$BAR="
        else
            BAR=""
        fi
        printf "\r[%s] Updating..." "\$BAR"
        sleep 0.2
    done
    wait \$PID
    printf "\r[%s] Update complete!          \n" "\$(printf '=%.0s' \$(seq 1 \$WIDTH))"
    sleep 2
    ;;
5)
    clear
    echo -e "\e[42m=== Entering shell (bash )===\e[0m"
    echo "Type 'exit' to return to the Boot Menu."
    bash
    ;;
6)
    clear
    echo "=== Network Configuration ==="
    echo -e "\e[41mOnly arrow keys, enter, and back are supported on controller.\e[0m"
    echo -e "\e[42mLaunching nmtui...\e[0m"
    sleep 1
    $PS3_PYTHON &
    PS3_PID=\$!
    sudo nmtui
    kill \$PS3_PID 2>/dev/null || true
    echo "Network configuration done!"
    sleep 2
    ;;
7)
    kill \$PS3_PID 2>/dev/null || true
    sudo reboot
    ;;
8)
    kill \$PS3_PID 2>/dev/null || true
    sudo shutdown now
    ;;
esac
done
EOF
sudo chmod +x $BOOTMENU

# --- Step 3: Auto-login + boot menu on tty1 ---
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER_NAME --noclear %I \$TERM
EOF
sudo systemctl daemon-reexec
grep -qxF '[ "$(tty)" = "/dev/tty1" ] && exec /usr/local/bin/bootmenu.sh' ~/.bash_profile || \
echo '[ "$(tty)" = "/dev/tty1" ] && exec /usr/local/bin/bootmenu.sh' >> ~/.bash_profile

# --- Step 4: IceWM Menu ---
mkdir -p "$(dirname "$ICEWM_MENU")"
cat > "$ICEWM_MENU" << EOF
menuprog "apps" folder icewm-menu-fdo
prog Terminal x-terminal-emulator x-terminal-emulator
prog FileManager thunar thunar

sep

prog Restart IceWM restart icewm --restart
prog Logout logout logout
EOF

# --- Step 5: Autostart for XFCE4 ---
mkdir -p "$AUTOSTART_DIR"
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

# --- Step 6: Autostart for IceWM ---
mkdir -p ~/.icewm
cat > ~/.icewm/startup << EOF
#!/bin/bash
antimicrox --hidden --profile $ANTIMICROX_PROFILE &
onboard &
EOF
chmod +x ~/.icewm/startup

# --- Step 7: RetroArch Cores ---
echo "downloading retroarch lates cores"
mkdir -p ~/.config/retroarch/cores
cd ~/.config/retroarch/cores
sudo wget -r -np -nH --cut-dirs=4 -A "*.zip" https://buildbot.libretro.com/nightly/linux/x86_64/latest/
sudo find . -name "*.zip" -exec unzip -o {} \;
sudo find . -name "*.zip" -delete
echo -e "\e[42mAll RetroArch cores downloaded and extracted.\e[0m"

# ---step 8: configs ---
echo -e "conf will be here"

mv "$conf"/* "${USER_NAME}.conf"


# --- Done ---
echo -e "\e[42m=== Setup complete! Reboot to test ===\e[0m"
echo -e "\e[41mTo check errors, read ./log.txt\e[0m"
