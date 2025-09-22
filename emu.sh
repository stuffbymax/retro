#!/bin/bash
# Arch Linux RetroArch Console Setup (Intel GPU + Openbox Fallback + PS3 controller)

set -e
USER_HOME="/home/$USER"
PROFILE_DIR="$USER_HOME/.config/antimicrox"
PROFILE_FILE="$PROFILE_DIR/ps3_fallback.profile"

echo "=== Updating system and installing required packages ==="
sudo pacman -Syu --noconfirm \
    xorg-server xorg-xinit mesa mesa-utils xf86-video-intel \
    openbox tint2 retroarch onboard \
    xboxdrv antimicrox \
    networkmanager network-manager-applet \
    bluez bluez-utils blueman \
    ntfs-3g

echo "=== Enabling system services (NetworkManager, Bluetooth) ==="
sudo systemctl enable NetworkManager bluetooth
sudo systemctl start NetworkManager bluetooth

echo "=== Cleaning old configs ==="
rm -f "$USER_HOME/.xinitrc"
rm -f "$USER_HOME/.bash_profile"
rm -f "$USER_HOME/.config/openbox/autostart"
sudo rm -rf /etc/systemd/system/getty@tty1.service.d

echo "=== Setting up systemd autologin on TTY1 ==="
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo bash -c "cat > /etc/systemd/system/getty@tty1.service.d/override.conf" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF
sudo systemctl daemon-reexec

echo "=== Creating new ~/.xinitrc (Openbox) ==="
cat > "$USER_HOME/.xinitrc" <<'EOF'
exec openbox-session
EOF

echo "=== Creating new ~/.bash_profile (auto startx) ==="
cat > "$USER_HOME/.bash_profile" <<'EOF'
if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
    exec startx
fi
EOF

echo "=== Creating Openbox autostart (RetroArch first, fallback later) ==="
mkdir -p "$USER_HOME/.config/openbox"
cat > "$USER_HOME/.config/openbox/autostart" <<'EOF'
# Start RetroArch fullscreen at login
retroarch --fullscreen

# If RetroArch exits, start fallback environment
tint2 &
onboard &
antimicrox --profile ~/.config/antimicrox/ps3_fallback.profile &
EOF

echo "=== Creating AntimicroX PS3 profile ==="
mkdir -p "$PROFILE_DIR"
cat > "$PROFILE_FILE" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<antimicrox>
  <controller name="Sony PLAYSTATION(R)3 Controller" guid="030000004c0500006802000011010000">
    <!-- Map PS button to launch RetroArch -->
    <button index="16">
      <keycode>Return</keycode>
      <extra exec="/home/$USER/start_retroarch.sh"/>
    </button>
    <!-- Map SELECT+START to shutdown -->
    <button index="0" modifier="start">
      <extra exec="systemctl poweroff"/>
    </button>
    <!-- Map SELECT+PS to reboot -->
    <button index="0" modifier="ps">
      <extra exec="systemctl reboot"/>
    </button>
  </controller>
</antimicrox>
EOF

echo "=== Creating RetroArch manual launcher script ==="
cat > "$USER_HOME/start_retroarch.sh" <<'EOF'
#!/bin/bash
retroarch --fullscreen
EOF
chmod +x "$USER_HOME/start_retroarch.sh"

echo "=== Fixing ownership for user files ==="
chown -R $USER:$USER "$USER_HOME/.config" "$USER_HOME/.xinitrc" "$USER_HOME/.bash_profile" "$USER_HOME/start_retroarch.sh"

echo "=== Setup complete! Reboot to test ==="
