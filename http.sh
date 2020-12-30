#!/bin/bash

source var.sh

#----------------------------------Configuring Dependencies:--------------------------------------------------
cd ~
sudo -u postgres createuser taiga
sudo -u postgres createdb taiga -O taiga --encoding='utf-8' --locale=en_US.utf8 --template=template0

sudo rabbitmqctl add_user taiga $BASEPASS

sudo rabbitmqctl add_vhost taiga
sudo rabbitmqctl set_permissions -p taiga taiga ".*" ".*" ".*"

#----------------------------------BACKEND SETUP:-------------------------------------------------------------
cd ~
git clone https://github.com/taigaio/taiga-back.git taiga-back
cd taiga-back
git checkout stable

source /usr/share/virtualenvwrapper/virtualenvwrapper.sh

mkvirtualenv -p /usr/bin/python3 taiga

#Тут кастыль
grep -rl cairocffi requirements.txt | xargs perl -p -i -e 's/cairocffi==1.2.0/cairocffi/g'
grep -rl cairocffi requirements.txt | xargs perl -p -i -e 's/cryptography==3.3.1/cryptography/g'
grep -rl cairocffi requirements.txt | xargs perl -p -i -e 's/importlib-metadata==3.3.0/importlib-metadata/g'
grep -rl cairocffi requirements.txt | xargs perl -p -i -e 's/pillow==8.0.1/pillow/g'
#Конец костыля

pip install -r requirements.txt

python manage.py migrate --noinput
python manage.py loaddata initial_user
python manage.py loaddata initial_project_templates
python manage.py compilemessages
python manage.py collectstatic --noinput

python3 manage.py sample_data

echo "from .common import *

MEDIA_URL = \"http://${DOMAIN}/media/\"
STATIC_URL = \"http://${DOMAIN}/static/\"
SITES[\"front\"][\"scheme\"] = \"http\"
SITES[\"front\"][\"domain\"] = \"${DOMAIN}\"

SECRET_KEY = \"${SECRETKEY}\"

DEBUG = False
PUBLIC_REGISTER_ENABLED = True

DEFAULT_FROM_EMAIL = \"no-reply@example.com\"
SERVER_EMAIL = DEFAULT_FROM_EMAIL

#CELERY_ENABLED = True

EVENTS_PUSH_BACKEND = \"taiga.events.backends.rabbitmq.EventsPushBackend\"
EVENTS_PUSH_BACKEND_OPTIONS = {\"url\": \"amqp://taiga:${BASEPASS}@${BASEIP}:5672/taiga\"}
" > ~/taiga-back/settings/local.py

#----------------------------------FRONTEND SETUP:------------------------------------------------------------
cd ~
git clone https://github.com/taigaio/taiga-front-dist.git taiga-front-dist
cd taiga-front-dist
git checkout stable

cp ~/taiga-front-dist/dist/conf.example.json ~/taiga-front-dist/dist/conf.json
echo "{
    \"api\": \"http://${DOMAIN}/api/v1/\",
    \"eventsUrl\": \"ws://${DOMAIN}/events\",
    \"eventsMaxMissedHeartbeats\": 5,
    \"eventsHeartbeatIntervalTime\": 60000,
    \"eventsReconnectTryInterval\": 10000,
    \"debug\": true,
    \"debugInfo\": false,
    \"defaultLanguage\": \"en\",
    \"themes\": [\"taiga\"],
    \"defaultTheme\": \"taiga\",
    \"defaultLoginEnabled\": true,
    \"publicRegisterEnabled\": true,
    \"feedbackEnabled\": true,
    \"supportUrl\": \"https://tree.taiga.io/support/\",
    \"privacyPolicyUrl\": null,
    \"termsOfServiceUrl\": null,
    \"GDPRUrl\": null,
    \"maxUploadFileSize\": null,
    \"contribPlugins\": [],
    \"tagManager\": { \"accountId\": null },
    \"tribeHost\": null,
    \"importers\": [],
    \"gravatar\": false,
    \"rtlLanguages\": [\"ar\", \"fa\", \"he\"]
}" > ~/taiga-front-dist/dist/conf.json


#----------------------------------EVENTS SETUP:------------------------------------------------------------
cd ~
git clone https://github.com/taigaio/taiga-events.git taiga-events
cd taiga-events

curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
sudo apt-get install -y nodejs

npm install

cp config.example.json config.json

echo "{
    \"url\": \"amqp://taiga:${BASEPASS}@${BASEIP}:5672/taiga\",
    \"secret\": \"${SECRETKEY}\",
    \"webSocketServer\": {
        \"port\": 8888
    }
}" > config.json

sudo touch /etc/systemd/system/taiga_events.service
sudo bash -c 'echo "[Unit]
Description=taiga_events
After=network.target

[Service]
User=taiga
WorkingDirectory=/home/taiga/taiga-events
ExecStart=/bin/bash -c \"node_modules/coffeescript/bin/coffee index.coffee\"
Restart=always
RestartSec=3

[Install]
WantedBy=default.target" > /etc/systemd/system/taiga_events.service'

sudo systemctl daemon-reload
sudo systemctl start taiga_events
sudo systemctl enable taiga_events

#----------------------------------START AND EXPOSE TAIGA:--------------------------------------------------
sudo touch /etc/systemd/system/taiga.service

sudo bash -c 'echo "[Unit]
Description=taiga_back
After=network.target

[Service]
User=taiga
Environment=PYTHONUNBUFFERED=true
WorkingDirectory=/home/taiga/taiga-back
ExecStart=/home/taiga/.virtualenvs/taiga/bin/gunicorn --workers 4 --timeout 60 -b 127.0.0.1:8001 taiga.wsgi
Restart=always
RestartSec=3

[Install]
WantedBy=default.target" > /etc/systemd/system/taiga.service'

sudo systemctl daemon-reload
sudo systemctl start taiga
sudo systemctl enable taiga

#----------------------------------NGINX:-------------------------------------------------------------------
sudo rm /etc/nginx/sites-enabled/default
mkdir -p ~/logs
sudo touch /etc/nginx/conf.d/taiga.conf

sudo bash -c 'echo "server {
    listen 80 default_server;
    server_name _;

    large_client_header_buffers 4 32k;
    client_max_body_size 50M;
    charset utf-8;

    access_log /home/taiga/logs/nginx.access.log;
    error_log /home/taiga/logs/nginx.error.log;

    # Frontend
    location / {
        root /home/taiga/taiga-front-dist/dist/;
        try_files \$uri \$uri/ /index.html;
    }

    # Backend
    location /api {
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Scheme \$scheme;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass http://127.0.0.1:8001/api;
        proxy_redirect off;
    }

    # Admin access (/admin/)
    location /admin {
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Scheme \$scheme;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass http://127.0.0.1:8001$request_uri;
        proxy_redirect off;
    }

    # Static files
    location /static {
        alias /home/taiga/taiga-back/static;
    }

    # Media files
    location /media {
        alias /home/taiga/taiga-back/media;
    }

    # Events
    location /events {
        proxy_pass http://127.0.0.1:8888/events;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
}" > /etc/nginx/conf.d/taiga.conf'

sudo nginx -t
sudo systemctl restart nginx

#------------------------------------------------------------------------------------------------------------
sudo sed -i 's|^taiga.*||g' /etc/sudoers




