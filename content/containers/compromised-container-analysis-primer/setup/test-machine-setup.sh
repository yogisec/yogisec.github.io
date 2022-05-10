#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color

cd /home/ubuntu/setup/

echo -e "\n${RED}Installing Falco${NC}\n"
curl -s https://falco.org/repo/falcosecurity-3672BA8F.asc | apt-key add -
echo "deb https://download.falco.org/packages/deb stable main" | tee -a /etc/apt/sources.list.d/falcosecurity.list
apt-get update -y
apt-get -y install linux-headers-$(uname -r)
apt-get install -y falco

echo -e "\n${RED}Installing Wget${NC}\n"
apt-get install wget

echo -e "\n${RED}Configuring and Starting Faclo${NC}\n"
cp /home/ubuntu/setup/falco.yaml /etc/falco/falco/yaml
systemctl start falco

echo -e "\n${RED}Installing Docker${NC}\n"
apt-get install docker.io -y
docker pull vulnerables/web-dvwa

echo -e "\n${RED}Grabbing nc${NC}\n"
wget https://github.com/yunchih/static-binaries/raw/master/nc

echo -e "\n${RED}Building and running the webapp${NC}\n"
docker build -t webapp:v1.0 .
docker run -d --rm -it -p 80:80 webapp:v1.0

echo -e "\n${RED}Validating Web Server Running${NC}\n"
docker ps

