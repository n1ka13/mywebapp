set -e

echo " 1. Встановлення системних пакетів "
sudo apt update
sudo apt install -y mariadb-server nginx curl git gnupg nodejs npm

echo " 2. Створення користувачів та налаштування прав "

if id "student" &>/dev/null; then
    sudo userdel -r student
fi

if id "teacher" &>/dev/null; then
    sudo userdel -r teacher
fi

if id "operator" &>/dev/null; then
    sudo userdel -r operator
fi
if getent group operator &>/dev/null; then
    sudo groupdel operator
fi

if id "app" &>/dev/null; then
    sudo userdel app
fi

sudo useradd -m -s /bin/bash student
sudo useradd -m -s /bin/bash teacher
sudo useradd -r -s /bin/false app
sudo groupadd operator || true
sudo useradd -m -g operator -s /bin/bash operator
echo "student:BlaBleBla!10" | sudo chpasswd
echo "teacher:BlaBleBla!10" | sudo chpasswd
echo "operator:BlaBleBla!10" | sudo chpasswd

sudo usermod -aG sudo student
sudo usermod -aG sudo teacher

sudo bash -c 'cat > /etc/sudoers.d/operator << EOF
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl start mywebapp, /usr/bin/systemctl stop mywebapp, /usr/bin/systemctl restart mywebapp, /usr/bin/systemctl status mywebapp, /usr/bin/systemctl reload nginx
EOF'

echo " 3. Налаштування бази даних MariaDB "
sudo systemctl start mariadb
sudo mysql -e "CREATE DATABASE IF NOT EXISTS mywebapp_db;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'webapp_user'@'127.0.0.1' IDENTIFIED BY 'password';"
sudo mysql -e "GRANT ALL PRIVILEGES ON mywebapp_db.* TO 'webapp_user'@'127.0.0.1';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo " 4. Створення конфігів Systemd "
sudo bash -c 'cat > /etc/systemd/system/mywebapp.socket << EOF
[Unit]
Description=Socket for NodeJS MyWebApp

[Socket]
ListenStream=127.0.0.1:8080

[Install]
WantedBy=sockets.target
EOF'

sudo bash -c 'cat > /etc/systemd/system/mywebapp.service << EOF
[Unit]
Description=NodeJS MyWebApp Service
Requires=mywebapp.socket
After=network.target mariadb.service

[Service]
Type=simple
User=app
Group=app
WorkingDirectory=/opt/mywebapp
ExecStart=/usr/bin/node server.js --port 8080 --db-host 127.0.0.1 --db-user webapp_user --db-pass password --db-name mywebapp_db
Restart=on-failure
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF'

echo " 5. Налаштування папки веб-додатку "
sudo mkdir -p /opt/mywebapp
sudo cp -rf . /opt/mywebapp/
cd /opt/mywebapp
sudo chown -R app:app /opt/mywebapp
sudo npm install --omit=dev --unsafe-perm
sudo chown -R app:app /opt/mywebapp

echo " 6. Запуск сервісів Systemd "
sudo systemctl daemon-reload
sudo systemctl enable mywebapp.socket
sudo systemctl start mywebapp.socket

echo " 7. Налаштування Nginx як Reverse Proxy "
sudo rm -f /etc/nginx/sites-enabled/default
sudo bash -c 'cat > /etc/nginx/sites-available/mywebapp << EOF
server {
    listen 80;
    server_name localhost;

    access_log /var/log/nginx/mywebapp_access.log;
    error_log /var/log/nginx/mywebapp_error.log;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /notes {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /health/ {
        return 403;
    }
}
EOF'

sudo ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
sudo systemctl restart nginx

echo " 8. Створення файлу gradebook "
sudo mkdir -p /home/student
echo "10" | sudo tee /home/student/gradebook > /dev/null
sudo chown student:student /home/student/gradebook

echo "9. Блокування дефолтного користувача"
DEFAULT_USER=$SUDO_USER

if [ -n "$DEFAULT_USER" ] && [ "$DEFAULT_USER" != "root" ]; then
    sudo passwd -l "$DEFAULT_USER"
else
    echo "Дефолтного користувача не знайдено або скрипт запущено не через sudo."
fi
echo "✅ Автоматичне розгортання завершено успішно!"