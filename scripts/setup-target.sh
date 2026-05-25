#!/bin/bash
set -e

echo "Встановлення Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

echo "Налаштування прав SSH..."
echo "HostKeyAlgorithms +*" | sudo tee -a /etc/ssh/sshd_config
echo "PubkeyAcceptedAlgorithms +*" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart sshd

sudo mkdir -p /opt/mywebapp
sudo chown -R $USER:$USER /opt/mywebapp

echo "Сервер налаштовано"