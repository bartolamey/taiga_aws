#!/bin/bash

source var.sh

#----------------------------------Install packages:--------------------------------------------------
sudo apt-get update
sudo apt-get install -y build-essential binutils-doc autoconf flex bison libjpeg-dev
sudo apt-get install -y libfreetype6-dev zlib1g-dev libzmq3-dev libgdbm-dev libncurses5-dev
sudo apt-get install -y automake libtool curl git tmux gettext
sudo apt-get install -y nginx
sudo apt-get install -y rabbitmq-server redis-server
sudo apt-get install -y postgresql-9.5 postgresql-contrib-9.5
sudo apt-get install -y postgresql-doc-9.5 postgresql-server-dev-9.5
sudo apt-get install -y python3 python3-pip python3-dev virtualenvwrapper
sudo apt-get install -y libxml2-dev libxslt-dev
sudo apt-get install -y libssl-dev libffi-dev

#-----------------------------------Add user:---------------------------------------------------------
sudo useradd -p taiga -m -d /home/taiga taiga
sudo adduser taiga sudo
sudo bash -c 'echo "taiga ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers'
sudo cp -a /home/ubuntu/.ssh/ /home/taiga/.ssh/
sudo chmod 600 /home/taiga/.ssh/authorized_keys
sudo chmod 700 /home/taiga/.ssh/
sudo chown -R taiga:taiga /home/taiga/.ssh/

#sudo chmod 777 /home/ubuntu/install.sh
#sudo chmod 777 /home/ubuntu/http.sh
#sudo chmod 777 /home/ubuntu/var.sh

