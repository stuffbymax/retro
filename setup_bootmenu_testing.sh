#!/bin/bash
# setup_bootmenu.sh - PS3-style ASCII boot menu with gamepad, RetroArch, IceWM & XFCE4

set -e

USER_NAME=$(whoami)
BOOTMENU_PATH="/usr/local/bin/bootmenu.sh"
ICEWM_MENU="$HOME/.icewm/menu"
ANTIMICRO_PROFILE="$HOME/bootmenu_gamepad_profile.amgp"

echo "=== Installing required packages ==="
sudo apt update
sudo apt install -y retroarch icewm xfce4 xinit xserver-xorg-core xserver-xorg-input-all xserver-xorg-video-vesa dialog joystick antimicrox sudo

echo "=== Creating gamepad profile ==="
# Simple placeholder profile for AntimicroX
cat > "$ANTIMICRO_PROFILE" << EOF
# Map D-pad Up/Down/Left/Right to arrows, A/Cross to Enter
# Save your custom mapping in AntimicroX GUI and save it here
EOF

echo "=== Creating PS3-style boot menu script ==="
sudo tee $BOOTMENU_PATH > /dev/null << EOF
#!/bin/bash
# bootmenu.sh - PS3-style ASCII boot menu on tty1 with gamepad support

USER_NAME=$USER_NAME

# Start gamepad mapping
if command -v antimicrox >/dev/null 2>&1; then
    antimicrox --profile $ANTIMICRO_PROFILE &
    ANTIMICRO_PID=\$!
fi

OPTIONS=("RetroArch" "IceWM" "XFCE4" "Reboot" "Shutdown")

while true; do
    clear
    echo "==============================================="
    echo "        ▸  PS3-Style Boot Menu  ◂"
    echo "==============================================="
    echo
    for i in "\${!OPTIONS[@]}"; do
        printf " %d) %s\n" \$((i+1)) "\${OPTIONS[\$i]}"
    done
    echo
    echo "Use arrow keys or gamepad to select an option"
    echo -n "Enter choice [1-${#OPTIONS[@]}]: "
    read -r CHOICE

    case \$CHOICE in
        1)
            # Stop gamepad mapping for RetroArch
            if [ ! -z "\$ANTIMICRO_PID" ]; then
                kill \$ANTIMICRO_PID
                wait \$ANTIMICRO_PID 2>/dev/null
            fi
            if [ -f /home/\$USER_NAME/.config/retroarch/retroarch.cfg ]; then
                retroarch -f -c /home/\$USER_NAME/.config/retroarch/retroarch.cfg
            else
                retroarch -f
            fi
            ;;
        2)
            startx ~/.xinitrc_icewm
            ;;
        3)
            startx ~/.xinitrc_xfce4
            ;;
        4)
            sudo reboot
            ;;
        5)
            sudo shutdown now
            ;;
        *)
            echo "Invalid option"
            sleep 1
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

echo "=== Creating .xinitrc files for desktops ==="
cat > ~/.xinitrc_icewm << EOF
#!/bin/bash
exec icewm-session
EOF
chmod +x ~/.xinitrc_icewm

cat > ~/.xinitrc_xfce4 << EOF
#!/bin/bash
exec startxfce4
EOF
chmod +x ~/.xinitrc_xfce4

echo "=== Disabling LightDM if XFCE4 is installed ==="
if command -v xfce4-session >/dev/null 2>&1; then
    echo "XFCE4 detected. Disabling LightDM..."
    sudo systemctl disable lightdm
    sudo systemctl stop lightdm
fi

echo "=== Setup complete! ==="
echo "Reboot your system to see the PS3-style boot menu on tty1."
echo "Use a gamepad to navigate the menu; RetroArch will take full controller control."
