#!/bin/bash
# setup_bootmenu.sh - Full automated setup for Debian boot menu with RetroArch & IceWM

set -e

USER_NAME=$(whoami)
BOOTMENU_PATH="/usr/local/bin/bootmenu.sh"
ICEWM_MENU="$HOME/.icewm/menu"

echo "=== Installing required packages ==="
sudo apt update
sudo apt install -y retroarch icewm xinit xserver-xorg-core xserver-xorg-input-all xserver-xorg-video-vesa dialog sudo

echo "=== Creating boot menu script ==="
sudo tee $BOOTMENU_PATH > /dev/null << 'EOF'
#!/bin/bash
# bootmenu.sh - Text-based boot menu on tty1

while true; do
    CHOICE=$(dialog --clear --backtitle "Debian Boot Menu" \
        --title "Boot Menu" \
        --menu "Choose an option:" 15 50 6 \
        1 "Launch RetroArch (fullscreen)" \
        2 "Launch IceWM Desktop" \
        3 "Reboot" \
        4 "Shutdown" \
        3>&1 1>&2 2>&3)

    clear
    case $CHOICE in
        1)
            retroarch -f
            ;;
        2)
            startx
            ;;
        3)
            sudo reboot
            ;;
        4)
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

echo "=== Setup complete! ==="
echo "Reboot your system to see the boot menu in action on tty1."
