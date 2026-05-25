#!/bin/bash
set -e

sudo apt-get update
sudo apt-get install -y curl git

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
fi

sudo usermod -aG docker "$USER"

sudo apt-get install -y docker-compose-plugin

if ! grep -q "HostKeyAlgorithms +\*" /etc/ssh/sshd_config; then
    echo "HostKeyAlgorithms +*" | sudo tee -a /etc/ssh/sshd_config
fi
if ! grep -q "PubkeyAcceptedAlgorithms +\*" /etc/ssh/sshd_config; then
    echo "PubkeyAcceptedAlgorithms +*" | sudo tee -a /etc/ssh/sshd_config
fi
sudo systemctl restart sshd

sudo mkdir -p /opt/mywebapp
sudo chown -R "$USER":"$USER" /opt/mywebapp

sudo bash -c 'cat << EOF > /etc/systemd/system/mywebapp.service
[Unit]
Description=My Web App Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/mywebapp
ExecStart=/usr/bin/docker compose up -d --force-recreate
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable mywebapp.service