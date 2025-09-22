[Unit]
Description=RetroArch Launcher
After=network.target

[Service]
ExecStart=/usr/bin/retroarch
Restart=on-failure
RestartSec=2

ExecStopPost=/usr/local/bin/retroarch-exit.sh

[Install]
WantedBy=multi-user.target
