#!/usr/bin/env bash

#Ensure strict error handling
set -euo pipefail

echo "starting deploymet of ianalyzer. . ."

#Checking if the script is ruuning as a roo
if [[ $EUID -ne 0 ]]; then
    echo "CRITICAL: Permission Error"
    exit 1
fi

#Dynamically grab the user who is installing the script
REAL_USER="${SUDO_USER:-$(whoami)}"
echo "Installing for user: $REAL_USER"

#Creating the global enterprise directory
INSTALL_DIR="/opt/ianalyzer"
echo "Creating global directory at $INSTALL_DIR. . ."
mkdir -p "$INSTALL_DIR"

echo "Staging files. . ."
cp gather_metrics.sh analyzer.py ianalyzer.service ianalyzer.timer "$INSTALL_DIR/"

echo "Setting permissions for the executables. . ."
chmod +x "$INSTALL_DIR/gather_metrics.sh" "$INSTALL_DIR/analyzer.py"

echo "configuring application defaults. . ."
if [[ ! -f "$INSTALL_DIR/services.conf" ]]; then
    echo "sshd" > "$INSTALL_DIR/services.conf"
fi

if [[ ! -f "$INSTALL_DIR/endpoints.conf" ]]; then
    echo "https://1.1.1.1" > "$INSTALL_DIR/endpoints.conf"
fi

echo "Establishing security boundary (infra_monitoring). . ."
if ! getent group infra_monitoring > /dev/null; then
    groupadd infra_monitoring
fi

echo "Log File Initialization. . ."
LOG_FILE="/var/log/infra_analyzer.log"

#creating the log file
touch "$LOG_FILE"

#changing the group ownership of the log file to infra_monitoring
chgrp infra_monitoring "$LOG_FILE"

#setting permissions to so owner Owner can read/write, Group can read/write, Others can only read
chmod 664 "$LOG_FILE"


echo "...adding $REAL_USER to the security group"
#Adding the user to the new security group
usermod -aG infra_monitoring "$REAL_USER"

echo "Injecting variables into systemd templates..."
# Use sed to replace the placeholders with the actual paths and username
sed -i  "s|{{USER}}|$REAL_USER|g" "$INSTALL_DIR/ianalyzer.service"
sed -i "s|{{INSTALL_DIR}}|$INSTALL_DIR|g" "$INSTALL_DIR/ianalyzer.service"

echo "Deploying systemd service and timer. . ."
cp "$INSTALL_DIR/ianalyzer.service" /etc/systemd/system/
cp "$INSTALL_DIR/ianalyzer.timer" /etc/systemd/system/

echo "reloading services . . ."
systemctl daemon-reload
echo "enabling service . . ."
systemctl enable ianalyzer.timer
echo "starting services . . ."
systemctl start ianalyzer.timer

echo "================================================="
echo " SUCCESS: ianalyzer has been successfully deployed!"
echo "================================================="
echo "Security: Log file enforced at 664 for group 'infra_monitoring'."
echo "Note: You may need to log out and log back in for group changes to take effect."
echo ""
echo "Verify timer status : systemctl status ianalyzer.timer"
echo "Check health logs   : cat /var/log/infra_analyzer.log"
echo "Trigger manually    : $INSTALL_DIR/analyzer.py"
echo "================================================="