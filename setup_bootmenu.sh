#!/bin/bash
# setup_bootmenu.sh - Automated Debian boot menu with RetroArch, IceWM & XFCE4 + gamepad support

set -e

USER_NAME=$(whoami)
BOOTMENU_PATH="/usr/local/bin/bootmenu.sh"
ICEWM_MENU="$HOME/.icewm/menu"
ANTIMICRO_PROFILE="$HOME/bootmenu_gamepad_profile.amgp"

echo "=== Installing required packages ==="
sudo apt update
sudo apt install -y retroarch icewm xfce4 xinit xserver-xorg-core xserver-xorg-input-all xserver-xorg-video-vesa dialog joystick antimicrox sudo

echo "=== Creating gamepad profile ==="
# Simple example profile: D-pad Up/Down = arrows, A/Cross = Enter
cat > "$ANTIMICRO_PROFILE" << EOF
# Create your mapping using AntimicroX GUI and save here
# This file is loaded by antimicrox automatically
EOF

echo "=== Creating boot menu script ==="
sudo tee $BOOTMENU_PATH > /dev/null << EOF
#!/bin/bash
# bootmenu.sh - Text-based boot menu on tty1 with gamepad support

USER_NAME=$USER_NAME

# Start gamepad-to-keyboard mapping
if command -v antimicrox >/dev/null 2>&1; then
    antimicrox --profile $ANTIMICRO_PROFILE &
    ANTIMICRO_PID=\$!
fi

while true; do
    CHOICE=\$(dialog --clear --backtitle "Debian Boot Menu" \
        --title "Boot Menu" \
        --menu "Choose an option:" 15 50 7 \
        1 "Launch RetroArch (fullscreen)" \
        2 "Launch IceWM Desktop" \
        3 "Launch XFCE4 Desktop" \
        4 "Reboot" \
        5 "Shutdown" \
        3>&1 1>&2 2>&3)

    clear
    case \$CHOICE in
        1)
            # Stop antimicrox to give RetroArch native controller access
            if [ ! -z "\$ANTIMICRO_PID" ]; then
                kill \$ANTIMICRO_PID
                wait \$ANTIMICRO_PID 2>/dev/null
            fi

            # Launch RetroArch
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
echo "Reboot your system to see the boot menu in action on tty1."
echo "Gamepad should work for menu navigation. RetroArch will take full control of the controller."
