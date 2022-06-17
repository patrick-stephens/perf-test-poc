#!/bin/bash
sudo sh <<SCRIPT
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
apt-get update
apt-cache policy docker-ce

apt-get install -y docker-ce
systemctl status docker

curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod a+x /usr/local/bin/docker-compose

adduser perf-test
usermod -aG sudo perf-test
usermod -aG docker perf-test
SCRIPT
