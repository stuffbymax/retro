#!/bin/bash
# Arch Linux RetroArch Console Setup (Intel GPU + Openbox Fallback)

set -e

echo "Updating system and installing required packages..."
sudo pacman -Syu --noconfirm \
    retroarch \
    xorg-server xorg-xinit xorg-xrandr xorg-xsetroot xorg-xinput xorg-xprop xorg-xev xorg-xhost xterm \
    mesa mesa-utils xf86-video-intel \
    openbox tint2 \
    onboard \
    xboxdrv antimicrox \
    networkmanager network-manager-applet \
    bluez bluez-utils blueman \
    ntfs-3g

echo "Enabling NetworkManager and Bluetooth..."
sudo systemctl enable NetworkManager bluetooth
sudo systemctl start NetworkManager bluetooth

echo "Creating RetroArch wrapper script..."
cat << 'EOF' > ~/start_retroarch.sh
#!/bin/bash
sudo xboxdrv --daemon
retroarch
exec startx ~/start_wm.sh
EOF
chmod +x ~/start_retroarch.sh

echo "Creating Openbox fallback script..."
cat << 'EOF' > ~/start_wm.sh
#!/bin/sh
tint2 &
onboard &
antimicrox --profile ~/.config/antimicrox/retro_fallback.profile &
exec openbox-session
EOF
chmod +x ~/start_wm.sh

echo "Setting up auto-login on TTY1..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo bash -c 'cat << EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin '"$USER"' --noclear %I \$TERM
EOF'
sudo systemctl daemon-reexec

echo "Adding RetroArch auto-start to ~/.bash_profile..."
grep -qxF 'if [[ $(tty) == /dev/tty1 ]]; then exec ~/start_retroarch.sh; fi' ~/.bash_profile || \
echo 'if [[ $(tty) == /dev/tty1 ]]; then exec ~/start_retroarch.sh; fi' >> ~/.bash_profile

echo "Creating system-wide RetroArch shortcut..."
sudo bash -c 'cat << EOF > /usr/share/applications/retroarch.desktop
[Desktop Entry]
Name=RetroArch
Comment=Launch RetroArch
Exec='"$HOME"'/start_retroarch.sh
Icon=retroarch
Terminal=false
Type=Application
Categories=Game;Emulator;
EOF'
sudo chown root:root /usr/share/applications/retroarch.desktop
sudo chmod 755 /usr/share/applications/retroarch.desktop

echo "Setup complete! Reboot to start RetroArch automatically."
